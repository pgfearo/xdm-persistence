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
  
  <xsl:import href="../src/xdm-persistence.xsl"/>
  
  <xsl:param name="mode" as="xs:string" select="'write'"/>
  <xsl:param name="data-file" as="xs:string" select="'out/demo-ref-data.xml'"/>
  <xsl:param name="read-file" as="xs:string" select="'out/demo-ref-read.html'"/>
  
  <xsl:output method="text"/>
  
  <xsl:variable name="data-uri" as="xs:string" select="resolve-uri($data-file, static-base-uri())"/>
  <xsl:variable name="read-uri" as="xs:string" select="resolve-uri($read-file, static-base-uri())"/>
  
  <xsl:variable name="profile1" as="element()">
    <xsl:sequence select="doc('ref-doc1.xml')/*"/>
  </xsl:variable>
  <xsl:variable name="profile2" as="element()">
    <xsl:sequence select="doc('ref-doc2.xml')/*"/>
  </xsl:variable>
  
  <xsl:variable name="sampleValue" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'tags': array { 'mathematician', 'writer' },
      'profile1': $profile1,
      'profile2': $profile2,
      'active': true()
    }"/>
  
  <xsl:template name="xsl:initial-template">
    <xsl:choose>
      <xsl:when test="$mode eq 'write'">
        <xsl:call-template name="write"/>
      </xsl:when>
      <xsl:when test="$mode eq 'read'">
        <xsl:call-template name="read-into-html"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes" select="'Unknown mode: ' || $mode || ' (expected write or read)'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="write">
    <!-- indent="no", never "yes": pretty-printing inserts whitespace-only
         text nodes around element-only content (even single-child elements
         like $profile below), and those come back as real extra child
         nodes on xdm:parse() - see the README. -->
    <xsl:result-document href="{$data-uri}" method="xml" indent="no">
      <xsl:sequence select="xdm:serialize-with-refs($sampleValue)"/>
    </xsl:result-document>
    <xsl:sequence select="'Wrote ' || $data-uri || '&#10;'"/>
  </xsl:template>
  
  <xsl:template name="read-into-html">
    <xsl:variable name="restored" as="item()*" select="xdm:parse-with-refs(doc($data-uri))"/>
    <xsl:variable name="m" as="map(*)" select="$restored[1]"/>
    <xsl:result-document href="{$read-uri}" method="html" indent="yes" expand-text="yes">
      <html>
            <p>profile1 base-uri: {$m?profile1 => base-uri()}</p>
            <p>profile2 base-uri: {$m?profile2 => base-uri()}</p>
            <p><xsl:sequence select="'Read back ' || count($restored) || ' item(s) from ' || $data-uri || ':' || '&#10;'"/></p>
            <p><xsl:sequence select="'  name:   ' || $m?name || '&#10;'"/></p>
            <p><xsl:sequence select="'  born:   ' || $m?born || ' (' || xdm:type-name($m?born) || ')' || '&#10;'"/></p>
            <p><xsl:sequence select="'  tags:   ' || string-join($m?tags?*, ', ') || '&#10;'"/></p>
            <p><xsl:sequence select="'  active: ' || $m?active || '&#10;'"/></p>
            <p><xsl:sequence select="'  profile1 is a real element: ' || ($m?profile1 instance of element()) || ', bio=' || $m?profile1/people:bio || '&#10;'"/></p>
            <p><xsl:sequence select="'  profile2 is a real element: ' || ($m?profile2 instance of element()) || ', bio=' || $m?profile2/people:bio || '&#10;'"/></p>
      </html>
      
    </xsl:result-document>    
    
  </xsl:template>
  
</xsl:stylesheet>
