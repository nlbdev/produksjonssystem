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
    
    <xsl:param name="book-id"/>
    
    <!--
        Quickbase fields with book IDs:
        
        isbn.xml:
            7: "Tilvekstnummer"
        
        records.xml:
            13: Tilvekstnummer EPUB
            20: Tilvekstnummer DAISY 2.02 Skjønnlitteratur
            24: Tilvekstnummer DAISY 2.02 Studielitteratur
            28: Tilvekstnummer Punktskrift
            31: Tilvekstnummer DAISY 2.02 Innlest fulltekst
            32: Tilvekstnummer e-bok
            38: Tilvekstnummer ekstern produksjon
    -->
    <xsl:variable name="book-id-rows" select="if (ends-with(base-uri(/*), '/isbn.xml')) then ('7') else if (ends-with(base-uri(/*), '/records.xml')) then ('13','20','24','28','31','32','38') else ()" as="xs:string*"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="records">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="record">
        <xsl:variable name="book-ids" select="distinct-values(for $f in f[@id = $book-id-rows] return (if ($f/text()) then $f/text() else ()))"/>
        <xsl:message select="$book-ids"/>
        <xsl:if test="$book-id = $book-ids">
            <xsl:copy-of select="."/>
        </xsl:if>
    </xsl:template>
    
</xsl:stylesheet>
