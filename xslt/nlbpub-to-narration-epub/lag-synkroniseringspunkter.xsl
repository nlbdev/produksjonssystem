<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">


    <xsl:variable name="maks-antall-p-per-synkpunkt" as="xs:integer" select="15"/>

    <xsl:template match="section/p[descendant::span[@epub:type eq 'pagebreak']]" priority="5">
        <!-- section/p-elementer med sidetall skal gjengis som de er, og skal ikke wrappes i  noe
            Merk @priority som sikrer at den overstyres andre regler
        -->
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="
        section/p[(local-name(preceding-sibling::element()[1]) eq 'p') and not(preceding-sibling::element()[1]/descendant::span[@epub:type eq 'pagebreak'])]">
        <!-- Denne matcher alle section/p som følger etter en p (med mindre det har sidetall, se over)
            Slike p-elementer skal tas bort, ettersom de håndteres av template-under
        -->
        <!--Tar bort denne 
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="style" select="'text-decoration: line-through;'"/>
            <xsl:apply-templates/>
        </xsl:copy> -->
    </xsl:template>
    
    <xsl:template
        match="
            section/p[
            not(preceding-sibling::element())
            or
            (local-name(preceding-sibling::element()[1]) ne 'p')
            or
            preceding-sibling::element()[1]/descendant::span[@epub:type eq 'pagebreak']
            ]">
        <!-- Hvis dette p-elemnetet er
            det første barnet i section-elementet, eller
            det første p-elementet etter et annet element, eller
            det første p-elementet etter et p-element som inneholder sidetall
            Da skal følgende skje:
            Ta dette p-elementet, og alle etterfølgende p-elementer, fram til et element som ikke er p-element eller fram til et p-element som inneholder sidetall, og samle dem i et div-element.
            
        -->
        <xsl:variable name="alle-relevante-p-elementer" as="element()+">
            <xsl:sequence select="current()"/>
            <xsl:choose>
                <xsl:when
                    test="
                        every $e in following-sibling::element()
                        satisfies (local-name($e) eq 'p') and not($e/descendant::span[@epub:type eq 'pagebreak'])">
                    <!-- ALLE etterfølgende søsken er p-elementer, og ingen av dem inneholder sidetall, så gjør det enkelt: ta med alle etterfølgende søsken -->
                    <xsl:sequence select="following-sibling::element()"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- okay, ting er ikke så enkelt. Finn fram til første etterfølgende element som ikke er p, eller som er p, men inneholder sidetall -->
                    <xsl:variable name="neste-ikke-p" as="element()?"
                        select="following-sibling::element()[(local-name() ne 'p') or exists(descendant::span[@epub:type eq 'pagebreak'])][1]"/>
                    <!-- Og med utgangspunkt i gjeldende p, så velger vi alle etterfølgende p som er før dette avvikende elementet -->
                    <xsl:sequence select="following-sibling::p[. &lt;&lt; $neste-ikke-p]"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <!-- Gjør litt aritmetikk for å fordele disse p element jevnt i korrekt antall synkpunkter -->
        <xsl:variable name="antall-p" as="xs:integer" select="count($alle-relevante-p-elementer)"/>
        <xsl:variable name="antall-synkpunkter" as="xs:integer"
            select="xs:integer(ceiling($antall-p div $maks-antall-p-per-synkpunkt))"/>
        <xsl:variable name="antall-p-per-synkpunkt" as="xs:integer"
            select="xs:integer(ceiling($antall-p div $antall-synkpunkter))"/>
        <xsl:variable name="sp.id" as="xs:string" select="generate-id()"/>

        <xsl:for-each select="1 to $antall-synkpunkter - 1">
            <div class="synch-point-wrapper" id="{concat('nlb-sp-',$sp.id,'-',current())}"
                style="border:1mm solid red;">
                <xsl:apply-templates
                    select="$alle-relevante-p-elementer[(position() ge (current() - 1) * $antall-p-per-synkpunkt + 1) and position() le (current() * $antall-p-per-synkpunkt)]"
                    mode="inkluder-i-wrapper"/>
            </div>
        </xsl:for-each>
        <!-- Og så resten av avsnittene -->
        <div class="synch-point-wrapper" id="{concat('nlb-sp-',$sp.id,'-',$antall-synkpunkter)}"
            style="border:1mm solid blue;">
            <xsl:apply-templates
                select="$alle-relevante-p-elementer[position() ge (($antall-synkpunkter - 1) * $antall-p-per-synkpunkt + 1)]"
                mode="inkluder-i-wrapper"/>

        </div>
    </xsl:template>

    
    
   

    <xsl:template match="p" mode="inkluder-i-wrapper">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <!--<xsl:attribute name="style" select="'border:1pt solid green;'"/>-->
            <xsl:apply-templates/>
        </xsl:copy>

    </xsl:template>
</xsl:stylesheet>
