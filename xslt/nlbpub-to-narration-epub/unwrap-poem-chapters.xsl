<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no"/>
    
    <xsl:template match="/*">
        <xsl:variable name="result" as="element()">
            <xsl:next-match/>
        </xsl:variable>
        
        <xsl:apply-templates select="$result" mode="rename-hx"/>
    </xsl:template>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[count(section) = 1
                            and section[f:types(.) = ('z3998:poem', 'poem')]
                            and count(h1 | h2 | h3 | h4 | h5 | h6 | section/h1 | section/h2 | section/h3 | section/h4 | section/h5 | section/h6) le 1
                            and count(* except (section | h1 | h2 | h3 | h4 | h5 | h6)) = 0
                            and count(section/* except (section/div[f:types(.)='linegroup'] | section/h1 | section/h2 | section/h3 | section/h4 | section/h5 | section/h6))
                        ]">
        <!--
            - a section with exactly one sub-section
            - where that sub-section is a poem
            - and there's at most one headline in the main section or the poem
            - and there's nothing other than the poem and an optional headline in the main section
            - and there's nothing other than linegroups and an optional headline in the poem
        -->
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | section/@* except section/(@id, @name)"/>
            <xsl:attribute name="class" select="string-join((f:classes(.), f:classes(section)), ' ')"/>
            <xsl:attribute name="epub:type" select="string-join((f:types(.)[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')], f:types(section)), ' ')"/>
            <xsl:apply-templates select="section/preceding-sibling::node() | section/node() | section/following-sibling::node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6" mode="rename-hx">
        <xsl:element name="h{min((count(ancestor::section | ancestor::aside | ancestor::article), 6))}" exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@class, '\s+')"/>
    </xsl:function>
    
</xsl:stylesheet>