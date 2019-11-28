<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all" version="2.0">
    
    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 14.02.2018
    -->
    
    <!--
        Håndterer cover:
        * Fjerner opprinnelig representasjon av coveret
        * Bygger opp et nytt cover rett etter diverse NLB-info og legger inn (erstatter) overskrifter
        * Antar at (frontcover|rearcover|leftflap|rightflap) ligger på nivå 2
        * Dersom opprinnelig cover var plassert lengre ut i boka, så kan sidetall bli skikkelig fucked up
    -->
    <xsl:template match="*[fnk:epub-type(@epub:type, 'cover')]">
        <xsl:message>* Fjerner opprinnelig cover</xsl:message>
        <xsl:comment>Fjerner Opprinnelig cover</xsl:comment>
    </xsl:template>
    
    <xsl:template name="bygg-opp-cover">
        <xsl:param name="matter" as="xs:string"/>
        <xsl:message>* Bygger opp cover</xsl:message>
        <section epub:type="{$matter}" id="level1_nlb_cover">
            <xsl:apply-templates select="//*[fnk:epub-type(@epub:type, 'cover')]/*" mode="bygg-opp-cover"/>
        </section>
    </xsl:template>
    
    <xsl:template
        match="*[fnk:epub-type(@epub:type, 'cover')]/section[matches(@class, '^(frontcover|rearcover|leftflap|rightflap)$')]"
        mode="bygg-opp-cover">
        <section>
            <xsl:copy-of select="@class"/>
            <xsl:apply-templates mode="#current"/>
        </section>
    </xsl:template>
</xsl:stylesheet>
