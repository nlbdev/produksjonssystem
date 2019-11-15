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
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- update modification time and insert CSS stylesheet -->
    <xsl:template match="head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <meta name="dcterms:modified" content="{if ($modified) then $modified else format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]-[M00]-[D00]T[H00]:[m00]:[s00]Z')}"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <link rel="stylesheet" type="text/css" href="ebok.css"/>
            <xsl:text><![CDATA[
    ]]></xsl:text>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="meta[@name='dcterms:modified']"/>
    
    <!-- insert copyright and usage information right after the titlepage -->
    <xsl:template match="section[(tokenize(@epub:type,'\s+'), tokenize(@class,'\s+')) = 'titlepage']">
        <xsl:next-match/>
        
        <xsl:variable name="language" select="(/*/@xml:lang/string(.), /*/@lang/string(.), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
        <xsl:variable name="year" select="format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]')"/>
        <xsl:variable name="depth" select="max(//*[matches(local-name(),'^h\d$')]/xs:integer(replace(local-name(),'^h','')))"/>
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        <xsl:if test="not(upper-case($library) = ('NLB','STATPED','KABB'))">
            <xsl:message select="concat('Ukjent bibliotek i schema:library (`*850$a`): ', ($library,'(mangler)')[1])"/>
        </xsl:if>
        <section>
            <xsl:choose>
                <xsl:when test="upper-case($library) = 'NLB'">
                  <xsl:choose>
                      <xsl:when test="$language = 'no' or ends-with($language, '-NO')">
                          <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                              <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                              <p>Denne e-boka er produsert for: [Studentens navn], av Norsk lyd- og blindeskriftbibliotek i <xsl:value-of select="$year"/>
                                  med hjemmel i åndsverkslovens § 17, og kan kun kopieres til privat bruk. Eksemplaret kan ikke videredistribueres.
                                  Ved låneperiodens utløp skal alle digitale eksemplar destrueres eller returneres til produsenten.
                                  Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til ulovlig kopiering,
                                  kan medføre ansvar etter åndsverkloven.</p>
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
                      </xsl:otherwise>
                  </xsl:choose>
                </xsl:when>
                
                <xsl:when test="upper-case($library) = 'STATPED'">
                    <xsl:choose>
                        <xsl:when test="$language = 'no' or ends-with($language, '-NO')">
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                                <p>Informasjon om opphavsrett for Statped på norsk her.</p>
                            </section>
                        </xsl:when>
                        <xsl:otherwise>
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Copyright</h1>
                                <p>Information about copyright for Statped in english here.</p>
                            </section>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                
                <xsl:when test="upper-case($library) = 'KABB'">
                    <!-- Ingenting her enda -->
                </xsl:when>
            </xsl:choose>
            
            <xsl:choose>
                <xsl:when test="$language = 'no' or ends-with($language, '-NO')">
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
                        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
                        <xsl:if test="$library">
                            <figure class="image"><img alt="{$library} logo" src="{upper-case($library)}_logo.png"/></figure>
                        </xsl:if>
                    </section>
                </xsl:when>
                <xsl:otherwise>
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
                        <figure class="image"><img alt="NLB logo" src="NLB_logo.png"/></figure>
                    </section>
                </xsl:otherwise>
            </xsl:choose>
        </section>
    </xsl:template>
    
    <!-- make page numbers visible -->
    <xsl:template match="*[tokenize(@epub:type,'\s+')='pagebreak']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @title"/>
            
            <xsl:variable name="language" select="(ancestor-or-self::*/(@xml:lang/string(.), @lang/string(.)), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
            <xsl:choose>
                <xsl:when test="$language = 'en' or starts-with($language, 'en-')">
                    <xsl:text>Page </xsl:text>
                    <xsl:value-of select="@title"/>  
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Side </xsl:text>
                    <xsl:value-of select="@title"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template> 
    
</xsl:stylesheet>