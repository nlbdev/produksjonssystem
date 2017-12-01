<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlbprod="http://www.nlb.no/production"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>

    <xsl:template match="/qdbapi">
        <metadata>
            <xsl:namespace name="dcterms" select="'http://purl.org/dc/terms/'"/>
            <xsl:for-each select="/qdbapi/table/records/record/f">
                <xsl:sort select="@id"/>
                <xsl:apply-templates select="."/>
            </xsl:for-each>
        </metadata>
    </xsl:template>
    
    <xsl:template match="f">
        <xsl:message select="concat('Ingen regel for QuickBase-felt i ISBN-tabell: ', @id)"/>
    </xsl:template>
    
    <xsl:template match="f[@id='1']">
        <!-- timestamp / int64 (Date Created) -->
        <meta property="nlbprod:isbn.created">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='2']">
        <!-- timestamp / int64 (Date Modified) -->
        <meta property="nlbprod:isbn.modified">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='3']">
        <!-- recordid / int32 (Record ID#) -->
        <meta property="nlbprod:isbn.recordid">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='4']">
        <!-- userid / text (Record Owner) -->
        <meta property="nlbprod:isbn.owner">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='5']">
        <!-- userid / text (Last Modified By) -->
        <meta property="nlbprod:isbn.modifier">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='6']">
        <!-- text -->
        <meta property="nlbprod:isbn">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='7']">
        <!-- text -->
        <meta property="nlbprod:isbn.identifier">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='8']">
        <!-- text -->
        <meta property="nlbprod:isbn.title">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='9']">
        <!-- text -->
        <meta property="nlbprod:isbn.creator">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='10']">
        <!-- text -->
        <meta property="nlbprod:isbn.user">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>

</xsl:stylesheet>
