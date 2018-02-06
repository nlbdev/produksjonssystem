<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">


    <xsl:variable name="maks-antall-p-per-synkpunkt" as="xs:integer" select="15"/>

    <xsl:template
        match="
            section/p[
            not(preceding-sibling::element())
            or
            (local-name(preceding-sibling::element()[1]) ne 'p')]">
        <xsl:variable name="alle-relevante-p-elementer" as="element()+">
            <xsl:sequence select="current()"/>
            <xsl:choose>
                <xsl:when
                    test="
                        every $e in following-sibling::element()
                            satisfies local-name($e) eq 'p'">
                    <xsl:sequence select="following-sibling::element()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="neste-ikke-p" as="element()?"
                        select="following-sibling::element()[local-name() ne 'p'][1]"/>
                    <xsl:sequence select="following-sibling::p[. &lt;&lt; $neste-ikke-p]"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="antall-p" as="xs:integer" select="count($alle-relevante-p-elementer)"/>
        <xsl:variable name="antall-synkpunkter" as="xs:integer"
            select="xs:integer(ceiling($antall-p div $maks-antall-p-per-synkpunkt))"/>
        <xsl:variable name="antall-p-per-synkpunkt" as="xs:integer"
            select="xs:integer(ceiling($antall-p div $antall-synkpunkter))"/>
        <xsl:variable name="sp.id" as="xs:string" select="generate-id()"/>

        <xsl:for-each select="1 to $antall-synkpunkter - 1">
            <div class="synch-point-wrapper" id="{concat('nlb-sp-',$sp.id,'-',current())}">
                <xsl:apply-templates select="$alle-relevante-p-elementer[(position() ge (current()-1) * $antall-p-per-synkpunkt +1) and position() le (current() * $antall-p-per-synkpunkt)]" mode="inkluder-i-wrapper"></xsl:apply-templates>
            </div>
        </xsl:for-each>
        <!-- Og så restent av avsnittene -->
        <div class="synch-point-wrapper" id="{concat('nlb-sp-',$sp.id,'-',$antall-synkpunkter)}">
            <xsl:apply-templates select="$alle-relevante-p-elementer[position() ge (($antall-synkpunkter - 1) * $antall-p-per-synkpunkt +1)]" mode="inkluder-i-wrapper"></xsl:apply-templates>
            
        </div>
    </xsl:template>

    <xsl:template match="
            section/p[local-name(preceding-sibling::element()[1]) eq 'p']">
        <!--Tar bort denne 
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="style" select="'text-decoration: line-through;'"/>
            <xsl:apply-templates/>
        </xsl:copy> -->
    </xsl:template>

    <xsl:template match="p" mode="inkluder-i-wrapper">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <!--<xsl:attribute name="style" select="'border:1pt solid green;'"/>-->
            <xsl:apply-templates/>
        </xsl:copy>

    </xsl:template>
</xsl:stylesheet>
