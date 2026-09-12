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
       Serializes an arbitrary XPath 3.1 data model value (any item()*:
       nodes, maps, arrays, atomic values, in any combination/nesting) to
       an XML tree in the xdm: namespace that xdm-parser.xsl can read back
       into an equivalent value.
  -->

  <xsl:function name="xdm:serialize" as="document-node()">
    <xsl:param name="value" as="item()*"/>
    <xsl:document>
      <xdm:sequence>
        <xsl:sequence select="xdm:build-item-seq($value)"/>
      </xdm:sequence>
    </xsl:document>
  </xsl:function>

  <xsl:function name="xdm:serialize-to-string" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="serialize(xdm:serialize($value), map{'method':'xml', 'indent': true()})"/>
  </xsl:function>

  <!-- One xdm:item per item in the sequence. Used for the top-level value,
       for a map entry's value (item()*), and for an array member's value
       (item()*) - all three are "an arbitrary XDM sequence" in the same sense. -->
  <xsl:function name="xdm:build-item-seq" as="element(xdm:item)*">
    <xsl:param name="items" as="item()*"/>
    <xsl:for-each select="$items">
      <xdm:item>
        <xsl:sequence select="xdm:build-payload(.)"/>
      </xdm:item>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="xdm:build-payload" as="element()">
    <xsl:param name="item" as="item()"/>
    <xsl:variable name="nodeKind" as="xs:string?" select="xdm:node-kind($item)"/>
    <xsl:choose>
      <xsl:when test="exists($nodeKind)">
        <xsl:sequence select="xdm:build-node($item, $nodeKind)"/>
      </xsl:when>
      <xsl:when test="$item instance of map(*)">
        <xsl:sequence select="xdm:build-map($item)"/>
      </xsl:when>
      <xsl:when test="$item instance of array(*)">
        <xsl:sequence select="xdm:build-array($item)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="xdm:build-atomic($item)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

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

  <!-- Element and document nodes are self-describing XML already, so they
       need no wrapper vocabulary of their own: elements are copied inline,
       and a document's children are copied under xdm:document (a document
       node cannot itself be a child of an element). The remaining kinds
       have no native XML representation as a bare sequence item, so each
       gets a small dedicated wrapper. -->
  <xsl:function name="xdm:build-node" as="element()">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="kind" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$kind eq 'element'">
        <xsl:copy-of select="$node"/>
      </xsl:when>
      <xsl:when test="$kind eq 'document'">
        <xdm:document>
          <xsl:copy-of select="$node/node()"/>
        </xdm:document>
      </xsl:when>
      <xsl:when test="$kind eq 'text'">
        <xdm:text><xsl:value-of select="$node"/></xdm:text>
      </xsl:when>
      <xsl:when test="$kind eq 'comment'">
        <xdm:comment><xsl:value-of select="$node"/></xdm:comment>
      </xsl:when>
      <xsl:when test="$kind eq 'processing-instruction'">
        <xdm:pi name="{name($node)}"><xsl:value-of select="$node"/></xdm:pi>
      </xsl:when>
      <xsl:when test="$kind eq 'attribute'">
        <xdm:attribute name="{local-name($node)}" uri="{namespace-uri($node)}">
          <xsl:value-of select="$node"/>
        </xdm:attribute>
      </xsl:when>
      <xsl:otherwise> <!-- namespace -->
        <xdm:namespace prefix="{name($node)}" uri="{string($node)}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:build-map" as="element(xdm:map)">
    <xsl:param name="m" as="map(*)"/>
    <xdm:map>
      <xsl:for-each select="map:keys($m)">
        <xsl:variable name="k" as="xs:anyAtomicType" select="."/>
        <xsl:variable name="keyType" as="xs:string" select="xdm:type-name($k)"/>
        <xdm:entry key="{xdm:atomic-lexical($k)}" key-type="{$keyType}">
          <xsl:if test="$keyType eq 'xs:QName' and string-length(namespace-uri-from-QName($k)) gt 0">
            <xsl:attribute name="key-uri" select="namespace-uri-from-QName($k)"/>
          </xsl:if>
          <xsl:sequence select="xdm:build-item-seq($m($k))"/>
        </xdm:entry>
      </xsl:for-each>
    </xdm:map>
  </xsl:function>

  <xsl:function name="xdm:build-array" as="element(xdm:array)">
    <xsl:param name="a" as="array(*)"/>
    <xdm:array>
      <xsl:for-each select="1 to array:size($a)">
        <xdm:member>
          <xsl:sequence select="xdm:build-item-seq($a(.))"/>
        </xdm:member>
      </xsl:for-each>
    </xdm:array>
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
