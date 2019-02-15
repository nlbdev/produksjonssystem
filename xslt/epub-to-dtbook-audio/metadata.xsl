<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
    xmlns="http://www.daisy.org/z3986/2005/dtbook/" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        En del av denne koden kan forenkles eller fjernes, hvis man kan være sikker på at all nødvendig metadata er på plass i filen.
        Inntil da, får vi beholde den som den er
        
        Per Sennels, 14.02.2018
    -->
    
    <!-- For kjøring i produksjonssystemet -->
    <xsl:variable name="metadata" as="element()*" select="//meta"/>
    <!-- For kjøring på lokal PC -->
<!--    <xsl:variable name="metadata" as="element()*" select="doc($metadata.url)//meta"/>-->

    <!-- Antar her at boken er oversatt, HVIS OG BARE HVIS følgende metadata er gitt: 'dc:Language.original' og 'dc:Title.original'  -->
    <xsl:variable name="boken.er-oversatt" as="xs:boolean"
        select="fnk:metadata-finnes('dc:Language.original') or fnk:metadata-finnes('dc:Title.original') or fnk:metadata-finnes('dc:Contributor.translator')"/>

    <!-- Transformasjonen fortsetter selv om det er forventet metadata som mangler
        NB: Noe metadata som er plassert her bør flyttes over til essensiell, men er her foreløpig for at ting ikke skal stoppe hele tiden
    -->
    <xsl:variable name="metadata.forventet" as="xs:string*"
        select="
            (
            'dc:Creator', 'dc:Date.issued.original', 'dc:Publisher.original', 'schema:bookEdition.original', 'dc:Contributor.narrator',
            (: Det følgende er flyttet fra metadata.essensiell, ettersom dette testes bedra andre steder :)
            'schema:isbn', 'dc:Publisher.location.original', 'dc:Language',
            (: Legg til litt mer hvis boken er oversatt :)
            if ($boken.er-oversatt) then
            ('dc:Language.original', 'dc:Title.original', 'dc:Contributor.translator')
            else
            ''
            )
            [normalize-space(.) ne '']"/>

    <!-- Transformasjonen avbrytes hvsi det er essensiell metadata som mangler -->
    <xsl:variable name="metadata.essensiell" as="xs:string*"
        select="
            (
            )
            [normalize-space(.) ne '']"/>

    <xsl:template name="varsle-om-manglende-metadata-i-nlbpub">
        <xsl:message>* Tester metadata ... </xsl:message>
        <xsl:for-each select="$metadata.forventet">
            <xsl:call-template name="flagg-manglende-forventet-metadata">
                <xsl:with-param name="navn" select="current()"/>
            </xsl:call-template>
        </xsl:for-each>

        <!-- 20180903: fjerner denne
        <xsl:for-each select="$metadata.essensiell">
            <xsl:call-template name="flagg-manglende-essensiell-metadata">
                <xsl:with-param name="navn" select="current()"/>
            </xsl:call-template>
        </xsl:for-each>
         -->

        <!-- 20180803: og fjerner denne
        <xsl:choose>
            <xsl:when
                test="
                    (every $md in $metadata.forventet
                        satisfies fnk:metadata-finnes($md)) and (every $md in $metadata.essensiell
                        satisfies fnk:metadata-finnes($md))">
                <xsl:message terminate="no">
                    <xsl:text>* Metadata OK</xsl:text>
                </xsl:message>
            </xsl:when>
            <xsl:when
                test="
                    every $md in $metadata.essensiell
                        satisfies fnk:metadata-finnes($md)">
                <xsl:message terminate="no">
                    <xsl:text>* Metadata er mangelfull, men prosessen fortsetter</xsl:text>
                </xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">
                    <xsl:text>* Prosessen termineres. Utilstrekkelig metadata.</xsl:text>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
         -->
    </xsl:template>
   

    <xsl:template name="flagg-manglende-forventet-metadata">
        <xsl:param name="navn" as="xs:string" required="yes"/>
        <xsl:if test="not(fnk:metadata-finnes($navn))">
            <xsl:message terminate="no">
                <xsl:text>    Mangler forventet metadata: </xsl:text>
                <xsl:value-of select="$navn"/>
                <xsl:text>. Prosessen kan likevel fortsette.</xsl:text>
            </xsl:message>
        </xsl:if>
    </xsl:template>

    <xsl:template name="flagg-manglende-essensiell-metadata">
        <xsl:param name="navn" as="xs:string" required="yes"/>
        <xsl:if test="not(fnk:metadata-finnes($navn))">
            <xsl:message terminate="no">
                <xsl:text>    Mangler essensiell metadata: </xsl:text>
                <xsl:value-of select="$navn"/>
                <xsl:text>. Dette vil stanse prosessen.</xsl:text>
            </xsl:message>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
