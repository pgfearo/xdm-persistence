<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Round-trip test for a map whose values are XML nodes rather than
       atomic values: a plain element, a nested element, a namespaced
       element, a standalone attribute node, and a standalone text node.
       Passes if serialize(parse(serialize(v))) is deep-equal to
       serialize(v).
  -->

  <xsl:import href="../src/xdm-persistence.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="plainElement" as="element()">
    <greeting>hello</greeting>
  </xsl:variable>

  <xsl:variable name="nestedElement" as="element()">
    <outer><inner id="1">deep</inner></outer>
  </xsl:variable>

  <xsl:variable name="namespacedElement" as="element()">
    <ns:tag xmlns:ns="http://example.com/ns">value</ns:tag>
  </xsl:variable>

  <xsl:variable name="helper" as="element()">
    <item id="42">some text content</item>
  </xsl:variable>

  <xsl:variable name="attributeNode" as="attribute()" select="$helper/@id"/>
  <xsl:variable name="textNode" as="text()" select="$helper/text()"/>

  <xsl:variable name="sampleValue" as="item()*" select="
    map {
      'plainElement': $plainElement,
      'nestedElement': $nestedElement,
      'namespacedElement': $namespacedElement,
      'attr': $attributeNode,
      'text': $textNode
    }"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="serialized1" as="document-node()" select="xdm:serialize($sampleValue)"/>
    <xsl:variable name="restored" as="item()*" select="xdm:parse($serialized1)"/>
    <xsl:variable name="serialized2" as="document-node()" select="xdm:serialize($restored)"/>
    <xsl:variable name="passed" as="xs:boolean" select="deep-equal($serialized1, $serialized2)"/>

    <xsl:choose>
      <xsl:when test="$passed">
        <xsl:message select="'PASS: node-valued map round-trip serializes identically' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="'FAIL: second serialization differs from the first' || '&#10;'"/>
        <xsl:sequence select="'--- first ---' || '&#10;' || serialize($serialized1, map{'method':'xml', 'indent': true()}) || '&#10;'"/>
        <xsl:sequence select="'--- second ---' || '&#10;' || serialize($serialized2, map{'method':'xml', 'indent': true()}) || '&#10;'"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
