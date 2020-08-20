<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:output method="xhtml" indent="no" include-content-type="no" exclude-result-prefixes="#all"/>

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
    <xsl:template match="section[tokenize(@epub:type,'\s+') = 'titlepage']">
        <xsl:next-match/>
        
        <xsl:call-template name="create-copyright-page"/>
    </xsl:template>
    
    <!-- if there's no titlepage, insert copyright and usage information as the first frontmatter -->
    <xsl:template match="body/section[not(tokenize(@epub:type, '\s+') = ('cover', 'titlepage'))][1]">
        <xsl:if test="not(exists(../section[tokenize(@epub:type,'\s+') = 'titlepage']))">
            <xsl:call-template name="create-copyright-page"/>
        </xsl:if>
        
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template name="create-copyright-page">
        <xsl:variable name="language" select="(/*/@xml:lang/string(.), /*/@lang/string(.), /*/head/meta[@name='dc:language']/@content/string(.), lang(/*))[1]" as="xs:string"/>
        <xsl:variable name="year" select="format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]')"/>
        <xsl:variable name="depth" select="max(//*[matches(local-name(),'^h\d$')]/xs:integer(replace(local-name(),'^h','')))"/>
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        <xsl:if test="not(upper-case($library) = ('NLB','STATPED','KABB'))">
            <xsl:message select="concat('Ukjent bibliotek i schema:library (`*850$a`): ', ($library,'(mangler)')[1])"/>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="upper-case($library) = 'NLB'">
              <xsl:choose>
                  <xsl:when test="$language = ('en', 'eng')">
                      <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                          <h1 id="copyright-headline-{generate-id()}">Copyright</h1>
                          <p>This edition is produced by NLB in <xsl:value-of select="$year"/> pursuant to article 55
                              of the Norwegian Copyright Act and can be reproduced for private use only.
                              This copy is not to be redistributed. All digital copies are to be destroyed or returned to the publisher
                              by the end of the borrowing period. The copy will be marked so that it will be possible to trace it
                              to the borrower if misused. Violation of these terms of agreement may lead to liability according to
                              the Copyright Act. Such actions may also result in loss of the right to borrow accessible literature.</p>
                      </section>
                  </xsl:when>
                  <xsl:when test="$language = ('nb', 'nob')">
                    <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                        <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                        <p>Denne utgaven er produsert av NLB i <xsl:value-of select="$year"/> med hjemmel i åndsverklovens § 55,
                            og kan kun kopieres til privat bruk. Eksemplaret kan ikke videredistribueres. Ved låneperiodens utløp
                            skal alle digitale eksemplar destrueres eller returneres til produsenten. Eksemplaret er merket slik
                            at det kan spores tilbake til deg som låner ved misbruk. Brudd på disse avtalevilkårene kan medføre ansvar
                            etter åndsverkloven. Slike handlinger kan også medføre tap av retten til å låne tilrettelagte bøker.</p>
                    </section>
                  </xsl:when>
                  <xsl:otherwise>
                      <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                          <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                          <p>Denne utgåva er produsert av NLB i <xsl:value-of select="$year"/> med heimel i åndsverklova § 55,
                              og kan bare kopierast til privat bruk. Eksemplaret kan ikkje distribuerast vidare. Når låneperioden er over,
                              skal alle digitale eksemplar destruerast eller returnerast til produsenten. Eksemplaret er merka slik
                              at det kan sporast tilbake til deg som lånar ved misbruk. Brot på desse avtalevilkåra kan medføre ansvar
                              etter åndsverklova. Slike handlingar kan også medføre tap av retten til å låne tilrettelagde bøker.</p>
                      </section>
                  </xsl:otherwise>
              </xsl:choose>
            </xsl:when>

            <xsl:when test="upper-case($library) = 'STATPED'">
                <section>
                    <xsl:choose>
                        <xsl:when test="$language = ('en', 'eng')">
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Copyright</h1>
                                <p>Information about copyright for Statped in english here.</p>
                            </section>
                            <section epub:type="frontmatter" id="bookinfo-section-{generate-id()}">
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
                                <figure class="image"><img alt="NLB logo" src="{upper-case($library)}_logo.png"/></figure>
                            </section>
                        </xsl:when>
                        <xsl:otherwise>
                            <section epub:type="frontmatter copyright-page" id="copyright-section-{generate-id()}">
                                <h1 id="copyright-headline-{generate-id()}">Opphavsrett</h1>
                                <p>Informasjon om opphavsrett for Statped på norsk her.</p>
                            </section>
                            <section epub:type="frontmatter" id="bookinfo-section-{generate-id()}">
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
                                <xsl:if test="$library">
                                    <figure class="image"><img alt="{$library} logo" src="{upper-case($library)}_logo.png"/></figure>
                                </xsl:if>
                            </section>
                        </xsl:otherwise>
                    </xsl:choose>
                </section>
            </xsl:when>

            <xsl:when test="upper-case($library) = 'KABB'">
                <!-- Ingenting her enda -->
            </xsl:when>
        </xsl:choose>
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

    <!-- p is not allowed in captions -->
    <xsl:template match="caption/p">
        <span>
            <xsl:apply-templates select="@* | node()"/>
        </span>
        <xsl:if test="following-sibling::*">
            <br/>
        </xsl:if>
    </xsl:template>
    
    <!-- make it possible to reference hidden headlines -->
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6">
        <xsl:variable name="whitespace" select="concat('&#xA;', string-join(for $a in (ancestor::*) return '    ', ''))"/>
        
        <xsl:choose>
            <xsl:when test="(preceding-sibling::div[1] intersect preceding-sibling::*[1])[tokenize(@class, '\s+') = 'hidden-headline-anchor']">
                <!-- hidden-headline-anchor already present: do nothing -->
            </xsl:when>
            
            <xsl:when test="not(@id)">
                <!-- if there's no id for some reason: generate one -->
                <div id="generated-headline-{generate-id()}" class="hidden-headline-anchor"></div>
                <xsl:value-of select="$whitespace"/>
            </xsl:when>
            
            <xsl:otherwise>
                <div id="{@id}" class="hidden-headline-anchor"></div>
                <xsl:value-of select="$whitespace"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <!-- copy the headline itself, excluding the id attribute -->
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @id"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
