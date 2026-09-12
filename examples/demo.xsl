<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Demonstrates xdm-persistence end to end. mode=write serializes a
       sample value (a map holding strings, a date, an array, a boolean,
       and a real namespaced element) to disk; mode=read parses that file
       back into an equivalent value in a later, independent run.

         java -jar saxon.jar -xsl:demo.xsl -it mode=write
         java -jar saxon.jar -xsl:demo.xsl -it mode=read
  -->

  <xsl:import href="../src/xdm-serializer.xsl"/>
  <xsl:import href="../src/xdm-parser.xsl"/>

  <xsl:param name="mode" as="xs:string" select="'write'"/>
  <xsl:param name="data-file" as="xs:string" select="'demo-data.xml'"/>

  <xsl:output method="text"/>

  <xsl:variable name="data-uri" as="xs:string" select="resolve-uri($data-file, static-base-uri())"/>

  <xsl:variable name="profile" as="element()">
    <people:person><people:bio>First programmer.</people:bio></people:person>
  </xsl:variable>

  <xsl:variable name="sampleValue" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'tags': array { 'mathematician', 'writer' },
      'profile': $profile,
      'active': true()
    }"/>

  <xsl:template name="xsl:initial-template">
    <xsl:choose>
      <xsl:when test="$mode eq 'write'">
        <xsl:call-template name="write"/>
      </xsl:when>
      <xsl:when test="$mode eq 'read'">
        <xsl:call-template name="read"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes" select="'Unknown mode: ' || $mode || ' (expected write or read)'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="write">
    <xsl:result-document href="{$data-uri}" method="xml" indent="yes">
      <xsl:sequence select="xdm:serialize($sampleValue)"/>
    </xsl:result-document>
    <xsl:sequence select="'Wrote ' || $data-uri || '&#10;'"/>
  </xsl:template>

  <xsl:template name="read">
    <xsl:variable name="restored" as="item()*" select="xdm:parse(doc($data-uri))"/>
    <xsl:variable name="m" as="map(*)" select="$restored[1]"/>
    <xsl:sequence select="'Read back ' || count($restored) || ' item(s) from ' || $data-uri || ':' || '&#10;'"/>
    <xsl:sequence select="'  name:   ' || $m?name || '&#10;'"/>
    <xsl:sequence select="'  born:   ' || $m?born || ' (' || xdm:type-name($m?born) || ')' || '&#10;'"/>
    <xsl:sequence select="'  tags:   ' || string-join($m?tags?*, ', ') || '&#10;'"/>
    <xsl:sequence select="'  active: ' || $m?active || '&#10;'"/>
    <xsl:sequence select="'  profile is a real element: ' || ($m?profile instance of element()) || ', bio=' || $m?profile/people:bio || '&#10;'"/>
  </xsl:template>

</xsl:stylesheet>
