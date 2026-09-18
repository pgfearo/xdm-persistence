<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Basic round-trip test: build a map, serialize it, then parse that
       back. Passes if deep-equal($sampleValue, xdm:from-document(xdm:to-document($sampleValue)))
       - the core requirement documented in the README.
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
    <xsl:variable name="serialized" as="document-node()" select="xdm:to-document($sampleValue)"/>
    <xsl:variable name="restored" as="item()*" select="xdm:from-document($serialized)"/>
    <xsl:variable name="passed" as="xs:boolean" select="deep-equal($sampleValue, $restored)"/>

    <xsl:choose>
      <xsl:when test="$passed">
        <xsl:message select="'PASS: map round-trip preserves the original value' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="'FAIL: parsed value differs from the original' || '&#10;'"/>
        <xsl:sequence select="'--- serialized ---' || '&#10;' || serialize($serialized, map{'method':'xml', 'indent': true()}) || '&#10;'"/>
        <xsl:sequence select="'--- restored, re-serialized ---' || '&#10;' || serialize(xdm:to-document($restored), map{'method':'xml', 'indent': true()}) || '&#10;'"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
