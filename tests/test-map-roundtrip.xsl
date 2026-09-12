<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Basic round-trip test: build a map, serialize it, parse that back,
       then serialize the result again. The test passes if the two
       serializations are deep-equal - i.e. parse(serialize(v)) is
       something serialize() treats as identical to v, without relying on
       comparing against the original map directly (map key/value order
       is not significant, but deep-equal on the XML serializations is a
       stable, order-sensitive check that both round trips agree on).
  -->

  <xsl:import href="../src/xdm-persistence.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="sampleValue" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'tags': array { 'mathematician', 'writer' },
      'active': true(),
      'nested': map { 'x': 1, 'y': (2, 3) }
    }"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="serialized1" as="document-node()" select="xdm:serialize($sampleValue)"/>
    <xsl:variable name="restored" as="item()*" select="xdm:parse($serialized1)"/>
    <xsl:variable name="serialized2" as="document-node()" select="xdm:serialize($restored)"/>
    <xsl:variable name="passed" as="xs:boolean" select="deep-equal($serialized1, $serialized2)"/>

    <xsl:choose>
      <xsl:when test="$passed">
        <xsl:sequence select="'PASS: map round-trip serializes identically' || '&#10;'"/>
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
