<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:zxd="http://deltaxignia.com/ns/xdm-persistence/internal"
                exclude-result-prefixes="#all"
                version="4.0">

  <!--
       Checks that XPath 4.0 JNodes are persisted as the values they wrap,
       in both modes (xdm:to-document and xdm:to-document-with-refs): a
       JNode serializes exactly as its value does, and parses back as that
       value - a map, an array, an atomic value, or nothing for a JSON
       null - at the top level, in a sequence, as a map entry's value and
       as an array member. Its key and its position in its tree aren't
       kept.

       An XSLT 4.0 stylesheet, so it's not run by tests/run.sh, whose
       test-*.xsl files are XSLT 3.0 and run with any Saxon edition. It
       needs Saxon-PE or Saxon-EE 13 (Saxon-HE 13 rejects XPath 4.0
       syntax), with XPath 4.0 syntax enabled by Saxon's
       allowSyntaxExtensions:on option - see the README's Tests section
       for the command line.
  -->

  <xsl:import href="../../src/xdm-persistence.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="tree" select="jtree(map {
      'customer': map { 'name': 'Sam', 'tags': ['a', 'b'] },
      'lines': [map { 'sku': 'A' }, map { 'sku': 'B' }],
      'notes': ()
    })"/>

  <!-- each pair: a value with JNodes in it, and the same value with each JNode replaced by its value -->
  <xsl:variable name="cases" as="array(*)*" select="(
    [$tree/customer, map { 'name': 'Sam', 'tags': ['a', 'b'] }],
    [$tree/lines/*, (map { 'sku': 'A' }, map { 'sku': 'B' })],
    [$tree/customer/tags, ['a', 'b']],
    [$tree/customer/name, 'Sam'],
    [$tree/notes, ()],
    [map { 'k': $tree/customer/name }, map { 'k': 'Sam' }],
    [[$tree/customer/name, $tree/lines/*[1]], ['Sam', map { 'sku': 'A' }]]
  )"/>

  <xsl:variable name="caseLabels" as="xs:string*" select="
    'a JNode for a map', 'a sequence of JNodes', 'a JNode for an array', 'a JNode for an atomic value',
    'a JNode for a JSON null', 'a JNode as a map entry value', 'JNodes as array members'"/>

  <xsl:variable name="checkLabels" as="xs:string*" select="(
    'is-jnode: a JNode',
    'is-jnode: not a map, array, node, atomic value or function',
    'jnode-value: a JNode''s value',
    'jnode-path: a nested array member',
    $caseLabels ! ('to-document: ' || . || ' serializes as its value'),
    $caseLabels ! ('from-document: ' || . || ' parses back as its value'),
    $caseLabels ! ('with refs: ' || . || ' parses back as its value')
  )"/>

  <xsl:variable name="checkResults" as="xs:boolean*" select="(
    zxd:is-jnode($tree/customer),
    not(zxd:is-jnode(map {}) or zxd:is-jnode([]) or zxd:is-jnode(1) or zxd:is-jnode(concat#3)
        or zxd:is-jnode(parse-xml('&lt;a/&gt;'))),
    deep-equal(zxd:jnode-value($tree/lines/*[2]), map { 'sku': 'B' }),
    zxd:jnode-path($tree/lines/*[2]/sku) eq '/lines/*[2]/sku',
    $cases ! deep-equal(xdm:to-document(?1), xdm:to-document(?2)),
    $cases ! deep-equal(xdm:from-document(xdm:to-document(?1)), ?2),
    $cases ! deep-equal(xdm:from-document-with-refs(xdm:to-document-with-refs(?1)), ?2)
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="failedLabels" as="xs:string*" select="
      for $i in 1 to count($checkResults) return if (not($checkResults[$i])) then $checkLabels[$i] else ()"/>
    <xsl:choose>
      <xsl:when test="count($checkResults) ne count($checkLabels)">
        <xsl:message terminate="yes" select="'Test error: ' || count($checkResults) || ' results for ' || count($checkLabels) || ' labels'"/>
      </xsl:when>
      <xsl:when test="empty($failedLabels)">
        <xsl:message select="'PASS: JNodes persist as the values they wrap, in both modes' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: ' || string-join($failedLabels, ' | ')"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
