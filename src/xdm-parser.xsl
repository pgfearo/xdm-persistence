<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Reads back the XML tree produced by xdm-serializer.xsl into an
       equivalent XPath 3.1 data model value (item()*).
  -->

  <xsl:function name="xdm:parse" as="item()*">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="xdm:parse-item-seq($doc/xdm:sequence/xdm:item)"/>
  </xsl:function>

  <xsl:function name="xdm:parse-string" as="item()*">
    <xsl:param name="xml" as="xs:string"/>
    <xsl:sequence select="xdm:parse(parse-xml($xml))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-item-seq" as="item()*">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:for-each select="$items">
      <xsl:sequence select="xdm:parse-item(.)"/>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="xdm:parse-item" as="item()*">
    <xsl:param name="item" as="element(xdm:item)"/>
    <xsl:variable name="payload" as="element()" select="$item/*[1]"/>
    <xsl:choose>
      <xsl:when test="$payload/self::xdm:atomic">
        <xsl:sequence select="xdm:parse-atomic($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:map">
        <xsl:sequence select="xdm:parse-map($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:array">
        <xsl:sequence select="xdm:parse-array($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:text">
        <xsl:value-of select="string($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:comment">
        <xsl:comment><xsl:value-of select="string($payload)"/></xsl:comment>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:pi">
        <xsl:processing-instruction name="{string($payload/@name)}">
          <xsl:value-of select="string($payload)"/>
        </xsl:processing-instruction>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:attribute">
        <xsl:sequence select="xdm:parse-attribute($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:namespace">
        <xsl:sequence select="xdm:parse-namespace($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:document">
        <xsl:document>
          <xsl:sequence select="$payload/node()"/>
        </xsl:document>
      </xsl:when>
      <xsl:otherwise> <!-- a plain copied element node -->
        <xsl:sequence select="$payload"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:parse-atomic" as="xs:anyAtomicType">
    <xsl:param name="atomicEl" as="element(xdm:atomic)"/>
    <xsl:variable name="type" as="xs:string" select="xdm:resolve-type-name($atomicEl/@type)"/>
    <xsl:sequence select="
      if ($type eq 'xs:QName') then xdm:cast-qname($atomicEl/@uri, string($atomicEl))
      else xdm:cast-atomic($type, string($atomicEl))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-map" as="map(*)">
    <xsl:param name="mapEl" as="element(xdm:map)"/>
    <xsl:sequence select="
      map:merge(
        for $entry in $mapEl/xdm:entry
        return map:entry(xdm:parse-key($entry), xdm:parse-item-seq($entry/xdm:item)))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-key" as="xs:anyAtomicType">
    <xsl:param name="entry" as="element(xdm:entry)"/>
    <xsl:variable name="keyType" as="xs:string" select="xdm:resolve-type-name($entry/@key-type)"/>
    <xsl:sequence select="
      if ($keyType eq 'xs:QName') then xdm:cast-qname($entry/@key-uri, string($entry/@key))
      else xdm:cast-atomic($keyType, string($entry/@key))"/>
  </xsl:function>

  <xsl:function name="xdm:parse-array" as="array(*)">
    <xsl:param name="arrayEl" as="element(xdm:array)"/>
    <xsl:sequence select="
      fold-left($arrayEl/xdm:member, array{},
        function($acc, $m) { array:append($acc, xdm:parse-item-seq($m/xdm:item)) })"/>
  </xsl:function>

  <!-- Standalone attribute nodes cannot be constructed directly in XPath, so
       one is built on a throwaway element and then extracted. -->
  <xsl:function name="xdm:parse-attribute" as="attribute()">
    <xsl:param name="el" as="element(xdm:attribute)"/>
    <xsl:variable name="name" as="xs:string" select="$el/@name"/>
    <xsl:variable name="uri" as="xs:string" select="$el/@uri"/>
    <xsl:variable name="temp" as="element()">
      <xsl:element name="{$name}" namespace="{$uri}">
        <xsl:attribute name="{$name}" namespace="{$uri}" select="string($el)"/>
      </xsl:element>
    </xsl:variable>
    <xsl:sequence select="$temp/@*"/>
  </xsl:function>

  <!-- Same trick for a standalone namespace node. -->
  <xsl:function name="xdm:parse-namespace" as="namespace-node()">
    <xsl:param name="el" as="element(xdm:namespace)"/>
    <xsl:variable name="prefix" as="xs:string" select="$el/@prefix"/>
    <xsl:variable name="uri" as="xs:string" select="$el/@uri"/>
    <xsl:variable name="temp" as="element()">
      <xsl:element name="tmp">
        <xsl:namespace name="{$prefix}" select="$uri"/>
      </xsl:element>
    </xsl:variable>
    <xsl:sequence select="$temp/namespace::*[name() eq $prefix]"/>
  </xsl:function>

</xsl:stylesheet>
