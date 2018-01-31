<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all" version="2.0">
    
    
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
        <xsl:message>* Bygger opp cover</xsl:message>
        <section epub:type="frontmatter" id="level1_nlb_cover">
            <h1>Omslag</h1>
            <xsl:apply-templates select="//*[fnk:epub-type(@epub:type, 'cover')]/*"
                mode="brygg-opp-cover"/>
        </section>
    </xsl:template>
    
    <xsl:template
        match="*[fnk:epub-type(@epub:type, 'cover')]/section[matches(@class, '^(frontcover|rearcover|leftflap|rightflap)$')]"
        mode="brygg-opp-cover">
        <!-- TODO: Nynorsk og engelsk -->
        <xsl:variable name="overskrift" as="xs:string">
            <xsl:choose>
                <xsl:when test="@class eq 'frontcover'">
                    <xsl:value-of select="'Forside'"/>
                </xsl:when>
                <xsl:when test="@class eq 'rearcover'">
                    <xsl:value-of select="'Bakside'"/>
                </xsl:when>
                <xsl:when test="@class eq 'leftflap'">
                    <xsl:value-of select="'Venstre innbrett'"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Bare 'rightflap' som er mulig nå -->
                    <xsl:value-of select="'Høyre innbrett'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <section>
            <xsl:copy-of select="@class"/>
            <xsl:attribute name="id"
                select="concat('leve2_nlb_', translate(lower-case($overskrift), ' ', '_'))"/>
            <h2>
                <xsl:value-of select="$overskrift"/>
            </h2>
            <xsl:apply-templates mode="#current"/>
        </section>
    </xsl:template>
</xsl:stylesheet>
