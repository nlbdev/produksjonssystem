<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">


    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 14.02.2018
    -->
    

    <!-- This module is added in order to create a text file with some debug information
        DO NOT GENERATE A LOG UNLESS YOU ARE DEAD CERTAIN THAT YOU NEED TO AND WANT TO
    -->
    <!-- Only set the following to true() if you know what you are doing -->
    <xsl:variable name="LOG.generate" as="xs:boolean" select="false()"/>
    
    <!-- Replace the url below with whatever suits your needs -->
    <xsl:variable name="LOG.url" as="xs:string"
        select="concat('file:/C:/nlb/prosjekter/fulltekstprosjektet-og-epub/transformasjon-av-html5/logg-', $ID, '.txt')"/>

    <xsl:template name="generer-loggfil-hvis-etterspurt">
        <xsl:if test="$LOG.generate">
            <xsl:message>
                <xsl:text>* Genererer logg: </xsl:text>
                <xsl:value-of select="$LOG.url"/>
            </xsl:message>

            <xsl:result-document href="{$LOG.url}" method="text" encoding="windows-1252">
                <xsl:variable name="NL" as="xs:string" select="'&#10;'"/>
                <xsl:value-of select="concat('Fil: ', document-uri(/), $NL)"/>
                <xsl:value-of
                    select="concat('ID: ', $ID, ' (', current-dateTime(), ')', $NL)"/>
                <xsl:value-of select="concat('Tittel: ', //title, $NL)"/>
                <xsl:value-of select="concat('Bokmål: ', $SPRÅK.nb, $NL)"/>
                <xsl:value-of select="concat('Nynorsk: ', $SPRÅK.nn, $NL)"/>
                <xsl:value-of select="concat('Engelsk: ', $SPRÅK.en, $NL)"/>
                <xsl:value-of select="concat('Oversatt: ', $boken.er-oversatt, $NL)"/>
                <xsl:for-each select="$metadata.forventet">
                    <xsl:if test="not(fnk:metadata-finnes(current()))">
                        <xsl:value-of select="concat('! Mangler ', current(), $NL)"/>
                    </xsl:if>
                </xsl:for-each>

                <xsl:for-each select="$metadata.essensiell">
                    <xsl:if test="not(fnk:metadata-finnes(current()))">
                        <xsl:value-of select="concat('! Mangler ', current(), $NL)"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:value-of select="$NL"/>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>


</xsl:stylesheet>
