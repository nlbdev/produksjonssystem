<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:nlb="http://www.nlb.no/2018/xml" xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.nlb.no/2018/xml-elementhierarki"
    xmlns="http://www.nlb.no/2018/xml-elementhierarki" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
       Denne transformasjonen sammenligner to markupoversikter, som er resultatet av to transformasjoner med 'generer-markupoversikt.xsl'. Se egen dokumentasjon i den filen.
        
       Denne transformasjonen mottar to URLer som parametre ('filA' og 'filB'). Disse URLene peker til to filer med markupoversikter. 
       Disse filene leses og sammelignes, og dersom filA innneholder noe som ikke finnes i filB så presenteres det informasjon om antall avvik, 
       og det genereres en HTML-fil som lister opp XPATH-uttrykk som gjør det enkelt å finne disse avvikene i den XHTML-filen som er representert ved markupoversikten i filA.
       
       filA skal derfor referere til en markupoversikt for en innkommende EPUB-fil, mens filB skal referere til en EPUB-fil med referansemarkup.  
       
        
        Per Sennels, 3.7.2018
    -->
    <xsl:output method="text"/>
    <xsl:output name="xml-filer" method="xml" indent="yes" encoding="UTF-8"/>
    <xsl:output name="xhtml-filer" method="xhtml" indent="yes" encoding="UTF-8"/>

    <xsl:param name="filA" as="xs:string" select="'noe'"/>
    <xsl:param name="filB" as="xs:string" select="'annet'"/>
    <xsl:param name="rapport" as="xs:string?" select="''"/>

    
    <!-- Sikrer at vi har korrekt URL for de to filene som skal sammenlignes -->
    <xsl:variable name="filA.uri" as="xs:string"
        select="translate(
            if (starts-with($filA,'file:')) then $filA else concat('file:/',$filA),
            '\', 
            '/')"/>
    <xsl:variable name="filB.uri" as="xs:string"
        select="translate(
        if (starts-with($filB,'file:')) then $filB else concat('file:/',$filB),
        '\', 
        '/')"/>
    <xsl:variable name="moA" as="document-node()" select="doc($filA.uri)"/>
    <xsl:variable name="moB" as="document-node()" select="doc($filB.uri)"/>
    
    <xsl:variable name="navnA" as="xs:string" select="replace($moA/elementhierarki/@basert-på,'^.+/(.+\..+?)$','$1')"/>
    <xsl:variable name="navnB" as="xs:string" select="replace($moB/elementhierarki/@basert-på,'^.+/(.+\..+?)$','$1')"/>
    
    <xsl:variable name="navnA.kort" as="xs:string" select="replace($navnA, '^(.+)\..+$','$1')"/>
    <xsl:variable name="navnB.kort" as="xs:string" select="replace($navnB, '^(.+)\..+$','$1')"/>

    <xsl:variable name="avviksliste" as="element()">
        <liste>
            <xsl:attribute name="time-stamp" select="current-dateTime()"/>
            <xsl:for-each select="$moA//element">
                <xsl:choose>
                    <xsl:when
                        test="
                            not(some $e in $moB//element
                                satisfies $e eq current())">
                        <avvik>
                            <xsl:value-of select="."/>
                        </avvik>
                    </xsl:when>
                    <xsl:otherwise>
                        <ok>
                            <xsl:value-of select="."/>
                        </ok>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </liste>
    </xsl:variable>



    <xsl:template name="start">
        <xsl:message>sammenlign-markupoversikter.xsl (0.1.1 / 2018-07-05)</xsl:message>
        <xsl:message>
            <xsl:text>* Sammenligner markup i </xsl:text>
            <xsl:value-of select="$filA"/>
        </xsl:message>
        <xsl:message>
            <xsl:text>  med markup i </xsl:text>
            <xsl:value-of select="$filB"/>
        </xsl:message>

        <!-- Følgende fil er bare for dubugging, så ingen grunn til å skrive til disk -->
        <!--<xsl:result-document href="_markupavvik.xml" format="xml-filer">
            <xsl:copy-of select="$avviksliste"/>
        </xsl:result-document>-->

        <xsl:choose>
            <xsl:when test="exists($avviksliste/avvik)">
                <xsl:message>
                    <xsl:text>* Markup i filen </xsl:text>
                    <xsl:value-of select="$navnA"/>
                    <xsl:text> samsvarer bare </xsl:text>
                    <xsl:value-of
                        select="format-number(count($avviksliste/ok) div count($avviksliste/element()), '0.0%')"/>
                    <xsl:text> med markupen i filen </xsl:text>
                    <xsl:value-of select="$navnB"/>
                </xsl:message>
                <xsl:message>
                    <xsl:text>  Det er </xsl:text>
                    <xsl:value-of select="count($avviksliste/avvik)"/>
                    <xsl:text> former for avvik i markupen. Se egen rapport.</xsl:text>
                </xsl:message>

            </xsl:when>
            <xsl:otherwise>
                <xsl:message>
                    <xsl:text>* Markup i filen </xsl:text>
                    <xsl:value-of select="$navnA"/>
                    <xsl:text> samsvarer 100% med markupen i filen </xsl:text>
                    <xsl:value-of select="$navnB"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:call-template name="generer-rapport"/>
    </xsl:template>

    <xsl:template name="generer-rapport">
        <xsl:result-document href="{if ($rapport) then $rapport else concat('markupoversikt/', $navnA.kort, '-vs-', $navnB.kort, '.html')}"
            format="xhtml-filer">
            <html xml:lang="no" lang="no" xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>
                        <xsl:text>Sammenligning av markup i </xsl:text>
                        <xsl:value-of select="$navnA"/>
                        <xsl:text> med markup i </xsl:text>
                        <xsl:value-of select="$navnB"/>
                    </title>
                </head>
                <body>
                    <h1>
                        <xsl:text>Sammenligning av markup i </xsl:text>
                        <xsl:value-of select="$navnA"/>
                        <xsl:text> med markup i </xsl:text>
                        <xsl:value-of select="$navnB"/>
                    </h1>
                    <p>
                        <xsl:text>  Det er </xsl:text>
                        <xsl:value-of select="count($avviksliste/avvik)"/>
                        <xsl:text> former for avvik i markupen.</xsl:text>
                        <xsl:if test="exists($avviksliste/avvik)">
                            <xsl:text> Listen under gir </xsl:text>
                            <em>XPath</em>
                            <xsl:text>-uttrykk for å finne disse avvikende elementene.</xsl:text>
                        </xsl:if>
                    </p>
                    <xsl:if test="exists($avviksliste/avvik)">
                        <p>
                            <xsl:text>Du kan åpne filen </xsl:text>
                            <strong><xsl:value-of select="$navnA"/></strong>
                            <xsl:text> (</xsl:text>
                            <xsl:value-of select="$moA/elementhierarki/@basert-på"/>
                            <xsl:text>) </xsl:text>
                            <xsl:text> i XML-editoren </xsl:text>
                            <em>Oxygen</em>
                            <xsl:text>, og deretter kopiere ett og ett av uttrykkene under over i </xsl:text>
                            <em>Xpath/XQuery Builder</em>
                            <xsl:text> i </xsl:text>
                            <em>Oxygen</em>
                            <xsl:text> for å finne disse elementene.</xsl:text>
                        </p>
                        <ol id="errors">
                            <xsl:for-each select="$avviksliste/avvik">
                                <li class="error" style="padding-bottom:1ex;">
                                    <!--<xsl:value-of select="."/>
                                        <hr/>-->
                                    <code style="color:rgb(00,0,250);font-weight:bold;">
                                        <xsl:analyze-string select="current()" regex="\[(.+?)\]">
                                            <xsl:matching-substring>
                                                <!-- Her håndterer vi class-attributtet -->
                                                <span style="color:rgb(130,130,130);">
                                                    <xsl:text>[</xsl:text>
                                                </span>
                                                <span style="color:rgb(0,0,0);">
                                                    <xsl:text>@class</xsl:text>
                                                </span>
                                                <span style="color:rgb(130,130,130);">
                                                    <xsl:text> eq &apos;</xsl:text>
                                                </span>
                                                <span style="color:rgb(180,30,30);">
                                                    <xsl:value-of select="regex-group(1)"/>
                                                </span>
                                                <span style="color:rgb(130,130,130);">
                                                    <xsl:text>&apos;]</xsl:text>
                                                </span>
                                            </xsl:matching-substring>
                                            <xsl:non-matching-substring>
                                                <!-- Og her håndterer vi resten, som må analyseres ytterligere for å håndtere epub:type -->
                                                <xsl:analyze-string select="." regex="\((.+?)\)">
                                                    <xsl:matching-substring>
                                                        <xsl:choose>
                                                            <xsl:when test="count(tokenize(normalize-space(regex-group(1)), '\s')) eq 1">
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>[</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(0,0,0);">
                                                                    <xsl:text>@epub:type</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text> eq &apos;</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(20,120,20);">
                                                                    <xsl:value-of select="normalize-space(regex-group(1))"/>
                                                                </span>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>&apos;]</xsl:text>
                                                                </span>
                                                            </xsl:when>
                                                            <xsl:otherwise>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>[</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(0,0,0);">
                                                                    <xsl:text>@epub:type</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>]</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>[every $type in tokenize(normalize-space(</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(0,0,0);">
                                                                    <xsl:text>@epub:type</xsl:text>
                                                                </span>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>),'\s') satisfies $type = (</xsl:text>
                                                                </span>
                                                                <xsl:for-each
                                                                    select="tokenize(normalize-space(regex-group(1)), '\s')">
                                                                    <span style="color:rgb(130,130,130);">
                                                                        <xsl:text>&apos;</xsl:text>
                                                                    </span>
                                                                    <span style="color:rgb(20,120,20);">
                                                                        <xsl:value-of select="."/>
                                                                    </span>
                                                                    <span style="color:rgb(130,130,130);">
                                                                        <xsl:text>&apos;</xsl:text>
                                                                        <xsl:if test="position() lt last()">
                                                                            <xsl:text>, </xsl:text>
                                                                        </xsl:if>
                                                                    </span>
                                                                    
                                                                </xsl:for-each>
                                                                <span style="color:rgb(130,130,130);">
                                                                    <xsl:text>)]</xsl:text>
                                                                </span>
                                                            </xsl:otherwise>
                                                        </xsl:choose>
                                                    </xsl:matching-substring>
                                                    <xsl:non-matching-substring>
                                                        <!-- Og her er resten -->
                                                        <xsl:value-of select="."/>
                                                    </xsl:non-matching-substring>
                                                </xsl:analyze-string>
                                            </xsl:non-matching-substring>
                                        </xsl:analyze-string>
                                    </code>
                                </li>
                            </xsl:for-each>
                        </ol>
                    </xsl:if>
                </body>
            </html>

        </xsl:result-document>
    </xsl:template>

</xsl:stylesheet>
