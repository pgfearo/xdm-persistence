<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Round-trips through an actual file on disk, written with
       serialize(..., indent="no") as the README requires - not just an
       in-memory document-node() as the other tests do. This is the case
       that actually matters for real persistence, and the one that
       previously caught a real bug: indent="yes" inserts whitespace-only
       text nodes around element-only content (even a single-child
       element), which come back as real extra child nodes on xdm:parse()
       and silently break deep-equal. $sampleValue below deliberately
       includes both the single-element-only-child case (person/bio) and
       the multiple-adjacent-element-children case (family) that trigger
       that corruption, to make sure indent="no" actually avoids it.

       unparsed-text() + parse-xml() (rather than doc()) reads back the
       file that was just written, since Saxon forbids doc() on a URI
       written by xsl:result-document earlier in the same transformation -
       this gives a genuine text-level round trip in one file, the same as
       a separate process reading it later would see.
  -->

  <xsl:import href="../src/xdm-persistence.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="out-uri" as="xs:string" select="resolve-uri('out/file-roundtrip-data.xml', static-base-uri())"/>

  <xsl:variable name="person" as="element()">
    <people:person><people:bio>First programmer.</people:bio></people:person>
  </xsl:variable>

  <xsl:variable name="family" as="element()">
    <people:family><people:parent/><people:child/><people:child/></people:family>
  </xsl:variable>

  <xsl:variable name="sampleValue" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'profile': $person,
      'household': $family,
      'active': true()
    }"/>

  <xsl:template name="xsl:initial-template">
    <xsl:result-document href="{$out-uri}" method="xml" indent="no">
      <xsl:sequence select="xdm:serialize($sampleValue)"/>
    </xsl:result-document>

    <xsl:variable name="rawText" as="xs:string" select="unparsed-text($out-uri)"/>
    <xsl:variable name="reparsed" as="document-node()" select="parse-xml($rawText)"/>
    <xsl:variable name="restored" as="item()*" select="xdm:parse($reparsed)"/>
    <xsl:variable name="passed" as="xs:boolean" select="deep-equal($sampleValue, $restored)"/>

    <xsl:choose>
      <xsl:when test="$passed">
        <xsl:message select="'PASS: file round-trip (indent=no) preserves the original value' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: value read back from ' || $out-uri || ' differs from the original'"/>
        <xsl:message select="'--- restored profile child count ---' || '&#10;' || count($restored[1]?profile/node())
          || ' (expected ' || count($person/node()) || ')'"/>
        <xsl:message select="'--- restored household child count ---' || '&#10;' || count($restored[1]?household/node())
          || ' (expected ' || count($family/node()) || ')'"/>
        <xsl:message select="'--- persisted file ---' || '&#10;' || $rawText"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
