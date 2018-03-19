<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:output method="xhtml" indent="no" include-content-type="no"/>
    
    <xsl:param name="modified" as="xs:string?"/>

    <xsl:variable name="language" select="(/*/@xml:lang/string(.), /*/@lang/string(.), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
    
    <xsl:template match="div">
        <xsl:choose>
            <xsl:when test="$language = 'no' or ends-with($language, '-NO')">
                <span class="page-normal">Side <xsl:value-of select="@title"/></span>
            </xsl:when>
            <xsl:when test="$language = 'en' or starts-with($language, 'en-')">
                <span class="page-normal">Page <xsl:value-of select="@title"/></span>  
            </xsl:when>
        </xsl:choose>
    </xsl:template> 
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html[not(preceding-sibling::text()[contains(.,'&#xA;')])]">
        <xsl:text><![CDATA[
]]></xsl:text>
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="head/comment()"/>
    <xsl:template match="meta[@name='dcterms:modified']"/>
    <xsl:template match="meta[starts-with(@name,'nlbprod:')]" priority="0.5">
        <xsl:if test="starts-with(@name, 'nlbprod:isbn') or starts-with(@name,'nlbprod:identifier')">
            <xsl:copy-of select="." exclude-result-prefixes="#all"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:variable name="first-meta" select="(title | meta[@charset] | meta[@name='dc:identifier'])/(. | preceding-sibling::node())"/>
            <xsl:apply-templates select="$first-meta"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <meta name="dcterms:modified" content="{if ($modified) then $modified else format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]-[M00]-[D00]T[H00]:[m00]:[s00]Z')}"/>
            <xsl:apply-templates select="node() except $first-meta"/>
            <link rel="stylesheet" type="text/css" href="default.css"/>
        </xsl:copy>
    </xsl:template>
      
        <xsl:template match="section[(tokenize(@epub:type,'\s+'), tokenize(@class,'\s+')) = 'titlepage' or .//h1/tokenize(@class,'\s+') = 'title' or .//h1/tokenize(@epub:type,'\s+') = 'fulltitle']">
        <xsl:next-match/>
    
        <xsl:variable name="year" select="format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]')"/>
        <xsl:variable name="depth" select="max(//*[matches(local-name(),'^h\d$')]/xs:integer(replace(local-name(),'^h','')))"/>
        <section>
            <xsl:choose>
                <xsl:when test="$language = 'no' or ends-with($language, '-NO')">
                    <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                        <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                        <p>Denne e-boka er produsert for: [Studentens navn], av Norsk lyd- og blindeskriftbibliotek i <xsl:value-of select="$year"/>
                            med hjemmel i åndsverkslovens § 17a, og kan kun kopieres til privat bruk. Eksemplaret kan ikke videredistribueres.
                            Ved låneperiodens utløp skal alle digitale eksemplar destrueres eller returneres til produsenten.
                            Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til ulovlig kopiering,
                            kan medføre ansvar etter åndsverkloven.</p>
                    </section>
                    <section epub:type="frontmatter tip" id="bookinfo-section-{generate-id()}">
                        <h1 id="bookinfo-headline-{generate-id()}">Bokinformasjon</h1>
                        <p>E-boka er strukturert slik at overskriftene er plassert på <xsl:value-of select="if ($depth = 1) then 'ett nivå'
                            else concat(if ($depth = 2) then 'to'
                            else if ($depth = 3) then 'tre'
                            else if ($depth = 4) then 'fire'
                            else if ($depth = 5) then 'fem'
                            else 'seks',
                            ' nivåer')"/>.</p>
                        <p>E-boka er i formatet HTML. Dette formatet kan åpnes og leses i nettlesere eller i tekstbehandlingsprogram.
                            For å kunne redigere i teksten må e-boka åpnes i en tekstbehandler (for eksempel Microsoft Word eller LibreOffice Writer).</p>
                        <figure class="image"><img alt="NLB logo" src="NLB_logo.jpg"/></figure>
                    </section>
                </xsl:when>
                <xsl:otherwise>
                    <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                        <h1 id="copyright-headline-{generate-id()}">Copyright</h1>
                        <p>This electronic book is made exclusively for: [Studentens navn], by the Norwegian Library of Talking Books and Braille in <xsl:value-of select="$year"/>.
                            No part of this book may be reproduced or distributed in any form or by any means, to other people.
                            When the lending period expires, the book must be deleted or returned to the library.
                            The user of this book, is responsible for adhering to these requirements.</p>
                    </section>
                    <section epub:type="frontmatter tip" id="bookinfo-section-{generate-id()}">
                        <h1 id="bookinfo-headline-{generate-id()}">Book information</h1>
                        <p>The book has <xsl:value-of select="if ($depth = 1) then 'one level'
                            else concat(if ($depth = 2) then 'two'
                            else if ($depth = 3) then 'three'
                            else if ($depth = 4) then 'four'
                            else if ($depth = 5) then 'five'
                            else 'six',
                            ' levels')"/> of headings.</p>
                        <p>The format of this book is HTML. This file format can be opened in any web browser for reading,
                            or a text editor for editing purposes (for instance Microsoft Word or LibreOffice Writer).</p>
                        <figure class="image"><img alt="NLB logo" src="NLB_logo.jpg"/></figure>
                    </section>
                </xsl:otherwise>
            </xsl:choose>
        </section>
    </xsl:template>
    
</xsl:stylesheet>
