<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="xsl"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Shared between xdm-serializer.xsl and xdm-serializer-refs.xsl: the
       parts of building the xdm: tree that don't differ between the two
       serialization modes - atomic values never contain nodes, and node
       *kind* classification is the same regardless of how a node ends up
       represented (embedded inline vs. referenced into a pool). Not
       self-sufficient - relies on xdm-types.xsl (xdm:type-name) being
       imported alongside it, same as xdm-serializer.xsl/xdm-parser.xsl.
  -->

  <xsl:function name="xdm:node-kind" as="xs:string?">
    <xsl:param name="item" as="item()"/>
    <xsl:choose>
      <xsl:when test="$item instance of document-node()">document</xsl:when>
      <xsl:when test="$item instance of element()">element</xsl:when>
      <xsl:when test="$item instance of text()">text</xsl:when>
      <xsl:when test="$item instance of attribute()">attribute</xsl:when>
      <xsl:when test="$item instance of comment()">comment</xsl:when>
      <xsl:when test="$item instance of processing-instruction()">processing-instruction</xsl:when>
      <xsl:when test="$item instance of namespace-node()">namespace</xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:build-atomic" as="element(xdm:atomic)">
    <xsl:param name="v" as="xs:anyAtomicType"/>
    <xsl:variable name="type" as="xs:string" select="xdm:type-name($v)"/>
    <xdm:atomic type="{$type}">
      <xsl:if test="$type eq 'xs:QName' and string-length(namespace-uri-from-QName($v)) gt 0">
        <xsl:attribute name="uri" select="namespace-uri-from-QName($v)"/>
      </xsl:if>
      <xsl:value-of select="xdm:atomic-lexical($v)"/>
    </xdm:atomic>
  </xsl:function>

  <!-- Canonical lexical form for an atomic value. xs:QName is special-cased
       to its local name since the namespace URI is captured separately
       (see xdm:build-atomic / xdm:build-map's key-uri). -->
  <xsl:function name="xdm:atomic-lexical" as="xs:string">
    <xsl:param name="v" as="xs:anyAtomicType"/>
    <xsl:sequence select="
      if ($v instance of xs:QName) then local-name-from-QName($v)
      else serialize($v, map{'method':'text'})"/>
  </xsl:function>

</xsl:stylesheet>
