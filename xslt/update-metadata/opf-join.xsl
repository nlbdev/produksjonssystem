<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:nordic="http://www.mtm.se/epub/"
                xmlns:dcterms="http://purl.org/dc/terms/"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="metadata-dir" required="yes" as="xs:string"/>
    <xsl:param name="opf-files" required="yes" as="xs:string"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy copy-namespaces="no">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="package">
        <xsl:copy copy-namespaces="no">
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="dcterms" select="'http://purl.org/dc/terms/'"/>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="metadata">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
            <xsl:variable name="opfs" select="for $opf-file in (tokenize($opf-files,' ')) return document(resolve-uri($opf-file, resolve-uri($metadata-dir)))/*" as="element()*"/>
            <xsl:variable name="book-metadata" select="."/>
            <xsl:for-each select="$opfs">
                <xsl:variable name="opf-name" select="replace(replace(base-uri(.),'.*/',''),'.opf$','')"/>
                <xsl:text>

</xsl:text>
                <xsl:comment select="concat(' [start ',$opf-name,'] ')"/>
                <xsl:text>
</xsl:text>
                <xsl:copy-of select="//metadata/*"/>
                <xsl:comment select="concat(' [end ',$opf-name,'] ')"/>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>
