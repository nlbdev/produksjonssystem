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
    
    <!-- Note: this XSLT takes about 30 minutes to run -->
    
    <xsl:param name="output-dir"/>
    <xsl:variable name="outputDir" select="if (ends-with($output-dir,'/')) then $output-dir else concat($output-dir,'/')"/>
    
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
    
    <!-- Discard all nodes unless explicitly included -->
    <xsl:template match="@* | node()"/>
    
    <xsl:template match="/qdbapi">
        <xsl:variable name="records" as="element()*">
            <xsl:for-each select="/qdbapi/table/records/record">
                <xsl:variable name="book-ids" select="distinct-values(for $f in f[@id = $book-id-rows] return (if ($f/text()) then $f/text() else ()))"/>
                <_ book-ids="{string-join($book-ids,' ')}">
                    <xsl:copy-of select="."/>
                </_>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="all-book-ids" select="distinct-values(for $f in /qdbapi/table/records/record/f[@id = $book-id-rows] return (if ($f/text()) then $f/text() else ()))"/>
        <xsl:variable name="result-filename" select="if (ends-with(base-uri(/*), '/isbn.xml')) then 'quickbase-isbn.xml' else if (ends-with(base-uri(/*), '/records.xml')) then 'quickbase-record.xml' else 'quickbase-unknown.xml'" as="xs:string"/>
        <xsl:variable name="doc" select="/"/>
        <xsl:for-each select="$all-book-ids">
            <xsl:variable name="book-id" select="."/>
            <xsl:variable name="records" select="$records[tokenize(@book-ids,' ') = $book-id]"/>
            <xsl:result-document href="{resolve-uri(concat($book-id,'/',$result-filename), resolve-uri($outputDir))}">
                <xsl:for-each select="$doc/qdbapi">
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:for-each select="table">
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:for-each select="* except queries">
                                    <xsl:copy>
                                        <xsl:copy-of select="@*"/>
                                        <xsl:choose>
                                            <xsl:when test="self::records">
                                                <xsl:copy-of select="$records/*"/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:copy-of select="."/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:copy>
                                </xsl:for-each>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:result-document>
        </xsl:for-each>
        
        <result book-ids="{string-join($all-book-ids,' ')}"/>
    </xsl:template>
    
</xsl:stylesheet>
