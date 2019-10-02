<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:f="#"
    xmlns="http://www.daisy.org/z3986/2005/dtbook/"
    xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/" exclude-result-prefixes="#all"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 15.01.2019
    -->
    
    <!--
        Dette er en transformasjon som foregår etter konverteringen fra NLBPUB til DTBook, og etter transformasjonen 'dtbookcleanup'
        
        Det som håndteres i denne transformasjonen er tabeller (se informasjon i filen 'tts-tabeller.xsl') og lister (se informasjon i filen 'lister.xsl').
        De øvrige filene som inkluderes under håndterer mindre spennende ting, for eksempel språk i boken og lignende.
        En del variabler/funksjoner som defineres i disse filene brukes ikke i denne transformasjonen, så de kan jo gentlig slettes eller kommenteres vekk.
        Men jeg har latt dem stå; de forstyrrer jo ikke
    -->
    <xsl:include href="funksjoner.xsl"/>
    <xsl:include href="metadata.xsl"/>
    <xsl:include href="struktur-etc.xsl"/>
    
    <xsl:include href="lister.xsl"/>
    <xsl:include href="tts-tabeller.xsl"/>
    <xsl:include href="ekstra-informasjon.xsl"/>

    <xsl:output indent="no" doctype-public="-//NISO//DTD dtbook 2005-3//EN"/>

    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>



</xsl:stylesheet>
