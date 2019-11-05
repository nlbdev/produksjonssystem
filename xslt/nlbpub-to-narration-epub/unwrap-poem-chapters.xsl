<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:html="http://www.w3.org/1999/xhtml"
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
    
    <xsl:template match="section">
        <!-- apply templates to descendant first, so that we can process the document tree bottoms-up, and thus "bubble poems upwards" if necessary (probably not necessary though) -->
        <xsl:variable name="content" as="node()*">
            <xsl:apply-templates select="node()"/>
        </xsl:variable>
        
        <!-- find the relevant elements: headline and poem -->
        <xsl:variable name="headline" as="element()?" select="$content[local-name() = ('h1', 'h2', 'h3', 'h4', 'h5', 'h6')][1]"/>
        <xsl:variable name="poem" as="element()?" select="$content[local-name() = 'section' and tokenize(@epub:type, '\s+') = 'z3998:poem'][1]"/>
        <xsl:variable name="poem-headline" as="element()?" select="$poem/*[local-name() = ('h1', 'h2', 'h3', 'h4', 'h5', 'h6')][1]"/>
        
        <!-- conditionally un-nest the poem -->
        <xsl:choose>
            <xsl:when test="exists($content except ($headline | $poem)) or not(exists($poem)) or exists($headline) and exists($poem-headline)">
                <xsl:next-match/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@*"/>
                    
                    <xsl:attribute name="class" select="string-join(distinct-values((tokenize(@class, '\s+'), tokenize($poem/@class, '\s+'))), ' ')"/>
                    <xsl:attribute name="epub:type" select="string-join(distinct-values((tokenize(@epub:type, '\s+'), tokenize($poem/@epub:type, '\s+'))), ' ')"/>
                    
                    <xsl:sequence select="$content except $poem"/>
                    <xsl:sequence select="$poem/node()"/>
                    
                    <!--<xsl:sequence select="$poem/preceding-sibling::node()"/>  <!-\- includes the headline, as well as any preceding comments and/or whitespace -\->
                    <xsl:sequence select="$poem/node()"/>  <!-\- here, we remove the nested section element -\->
                    <xsl:sequence select="$poem/following-sibling::node()"/>  <!-\- includes any trailing comments and/or whitespace -\->-->
                    
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6" mode="rename-hx">
        <xsl:element name="h{min((count(ancestor::section), 6))}" exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>