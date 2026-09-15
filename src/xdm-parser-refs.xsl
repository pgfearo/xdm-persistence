<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="xsl map array"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Reads back the xdm:context tree produced by xdm-serializer-refs.xsl.
       A distinct, opt-in mode from xdm-parser.xsl - does not read that
       format's plain xdm:sequence documents, and xdm-parser.xsl does not
       read this one's.

       Node identity is preserved for repeated references (xdm:parse(a) is
       xdm:parse(b) holds when a and b referenced the same original node),
       since every reference resolves against the one already-parsed pool
       document rather than being copied. Known trade-off for now:
       resolved nodes still carry the xdm:key marker attribute the pool
       copy needed for lookup - stripping it while preserving identity for
       repeated/cross references needs more machinery than this first cut
       has; worth revisiting.
  -->

  <xsl:import href="xdm-types.xsl"/>
  <xsl:import href="xdm-parser-common.xsl"/>

  <xsl:key name="xdm:anchor-by-key" match="*[@xdm:key]" use="@xdm:key"/>

  <xsl:function name="xdm:parse-with-refs" as="item()*">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="xdm:parse-item-seq($doc/xdm:context/xdm:sequence/xdm:item)"/>
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
      <xsl:when test="$payload/self::xdm:node-ref">
        <xsl:sequence select="xdm:resolve-node-ref($payload)"/>
      </xsl:when>
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

  <!-- Resolves one <xdm:node-ref key="..." pos="..."/> or
       <xdm:node-ref doc="..." pos="..."/> marker back to the actual node
       it addresses, per xdm-serializer-refs.xsl's xdm:anchor-of/
       xdm:position-code scheme. root($ref) is the whole persisted
       document (the reference marker is itself part of it), used to
       scope both the xsl:key lookup and the pool-doc-by-id lookup. -->
  <xsl:function name="xdm:resolve-node-ref" as="node()">
    <xsl:param name="ref" as="element(xdm:node-ref)"/>
    <xsl:variable name="pos" as="xs:string" select="$ref/@pos"/>
    <xsl:variable name="anchor" as="node()" select="
      if ($ref/@key)
      then key('xdm:anchor-by-key', string($ref/@key), root($ref))[1]
      else xdm:pool-doc-by-id(string($ref/@doc), root($ref))"/>
    <xsl:sequence select="xdm:navigate-from-anchor($anchor, $pos)"/>
  </xsl:function>

  <xsl:function name="xdm:pool-doc-by-id" as="element(xdm:pool-doc)">
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="($doc/xdm:context/xdm:documents/xdm:pool-doc[@id = $id])[1]"/>
  </xsl:function>

  <!-- Interprets one xdm:position-code value relative to $anchor (an
       element found via xsl:key, or an xdm:pool-doc found by id for the
       document-level fallback - xdm:pool-doc/node() corresponds 1:1, in
       order, to the original document's own node() children, same as
       when it was built). -->
  <xsl:function name="xdm:navigate-from-anchor" as="node()">
    <xsl:param name="anchor" as="node()"/>
    <xsl:param name="pos" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$pos eq '0'">
        <xsl:sequence select="$anchor"/>
      </xsl:when>
      <xsl:when test="starts-with($pos, '@')">
        <xsl:sequence select="xdm:find-attribute-by-eqname($anchor, substring($pos, 2))"/>
      </xsl:when>
      <xsl:when test="starts-with($pos, '{')">
        <xsl:sequence select="xdm:find-namespace-by-marker($anchor, $pos)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="($anchor/node())[xs:integer($pos)]"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- $eqname is the position-code with its leading '@' already stripped,
       e.g. 'Q{http://example.com/foo}attr' or 'Q{}plain'. -->
  <xsl:function name="xdm:find-attribute-by-eqname" as="attribute()">
    <xsl:param name="anchor" as="node()"/>
    <xsl:param name="eqname" as="xs:string"/>
    <xsl:variable name="uri" as="xs:string" select="substring-before(substring-after($eqname, 'Q{'), '}')"/>
    <xsl:variable name="local" as="xs:string" select="substring-after($eqname, '}')"/>
    <xsl:sequence select="($anchor/@*[namespace-uri(.) eq $uri and local-name(.) eq $local])[1]"/>
  </xsl:function>

  <!-- $marker is the full position-code, e.g. '{foo}http://example.com/foo'. -->
  <xsl:function name="xdm:find-namespace-by-marker" as="namespace-node()">
    <xsl:param name="anchor" as="node()"/>
    <xsl:param name="marker" as="xs:string"/>
    <xsl:variable name="prefix" as="xs:string" select="substring-before(substring-after($marker, '{'), '}')"/>
    <xsl:sequence select="($anchor/namespace::*[name() eq $prefix])[1]"/>
  </xsl:function>

</xsl:stylesheet>
