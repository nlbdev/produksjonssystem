<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 14.02.2018
    -->
    
    <xsl:template name="generer-startinformasjon">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <xsl:call-template name="generer-tittel"/>
        <!-- PSPS: Alltid før cover,sier Roald -->
        <xsl:call-template name="lydbokavtalen"/>
        <xsl:if test="not(upper-case($library) = 'STATPED')">
            <xsl:call-template name="info-om-boka"/>
        </xsl:if>
    </xsl:template>

    <xsl:template name="generer-tittel">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <section epub:type="frontmatter titlepage" id="nlb-level1-tittel">
            <h1 epub:type="fulltitle" class="title">
                <xsl:apply-templates select="//title/child::node()"/>
            </h1>
            <p>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>by </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>av </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                <xsl:text>.</xsl:text>
            </p>
            <p>
                <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>Read by </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text>.</xsl:text>
                    </xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:text>Det er </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text> som les.</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Det er </xsl:text>
                        <xsl:value-of
                            select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                        <xsl:text> som leser.</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </p>
            
            <xsl:if test="upper-case($library) = 'STATPED'">
                <figure class="image"><img alt="{$library} logo" src="{upper-case($library)}_logo.png"/></figure>
            </xsl:if>
        </section>
    </xsl:template>

    <xsl:template name="generer-sluttinformasjon">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <hr class="separator"/>
        <xsl:choose>
            
            <xsl:when test="upper-case($library) = 'STATPED'">
                <h1>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:text>Informasjon om originalbok og lydbok</xsl:text>
                </h1>
                <dl>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:variable name="title" select="ancestor::html/head/title/text()" as="xs:string?"/>
                    <xsl:variable name="authors" select="ancestor::html/head/meta[@name='dc:creator']/string(@content)" as="xs:string*"/>
                    <xsl:variable name="language" select="(ancestor-or-self::*/(@xml:lang/string(.), @lang/string(.)), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
                    <xsl:variable name="language" select="if (count($language)) then tokenize($language, '-')[1] else $language" as="xs:string?"/>
                    <xsl:variable name="originalPublisher" select="ancestor::html/head/meta[@name='dc:publisher.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalYear" select="ancestor::html/head/meta[@name='dc:date.issued.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalEdition" select="ancestor::html/head/meta[@name='schema:bookEdition.original']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="originalIsbn" select="ancestor::html/head/meta[@name='schema:isbn']/string(@content)" as="xs:string?"/>
                    <xsl:variable name="productionYear" select="format-date(current-date(), '[Y]')" as="xs:string"/>
                    
                    <dt>Boktittel:</dt>
                    <dd><xsl:value-of select="$title"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Forfattarar:' else 'Forfattere:'"/></dt>
                    <xsl:for-each select="$authors">
                        <dd><xsl:value-of select="."/></dd>
                    </xsl:for-each>
                    
                    <xsl:choose>
                        <xsl:when test="$language = ('nb', 'nn')">
                            <dt>Målform:</dt>
                        </xsl:when>
                        <xsl:otherwise>
                            <dt>Språk:</dt>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$language = 'no'">
                            <dd>Norsk</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'nb'">
                            <dd>Bokmål</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'nn'">
                            <dd>Nynorsk</dd>
                        </xsl:when>
                        <xsl:when test="$language = 'en'">
                            <dd>Engelsk</dd>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- TODO: koble flere språkkoder til språknavn -->
                            <dd><xsl:value-of select="$language"/></dd>
                        </xsl:otherwise>
                    </xsl:choose>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgjevar av originalboka:' else 'Utgiver av originalboka:'"/></dt>
                    <dd><xsl:value-of select="if ($originalPublisher) then $originalPublisher else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgjevingsår:' else 'Utgivelsesår:'"/></dt>
                    <dd><xsl:value-of select="if ($originalYear) then $originalYear else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Utgåve og opplag:' else 'Utgave og opplag:'"/></dt>
                    <dd><xsl:value-of select="if ($originalEdition) then $originalEdition else 'Ukjent'"/></dd>
                    
                    <dt>ISBN originalbok:</dt>
                    <dd><xsl:value-of select="if ($originalIsbn) then $originalIsbn else 'Ukjent'"/></dd>
                    
                    <dt><xsl:value-of select="if ($language = 'nn') then 'Ansvarleg utgjevar av lydboka:' else 'Ansvarlig utgiver av lydboka:'"/></dt>
                    <dd>Statped</dd>
                    
                    <dt>Produksjonsår:</dt>
                    <dd><xsl:value-of select="$productionYear"/></dd>
                </dl>
            </xsl:when>
            
            <xsl:otherwise>
                <p>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>You've been listening to </xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Du høyrde </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Du hørte </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                    <em>
                        <xsl:apply-templates select="//title/child::node()"/>
                    </em>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>, by </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>, av </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:value-of select="fnk:hent-metadata-verdi('dc:creator', false(), true())"/>
                    <xsl:text>.</xsl:text>
                </p>
                <p>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>Read by </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text>.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Det var </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text> som las.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Det var </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:contributor.narrator', false(), true())"/>
                            <xsl:text> som leste.</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </p>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="lydbokavtalen">
        <xsl:variable name="library" select="ancestor::html/head/meta[@name='schema:library']/string(@content)" as="xs:string?"/>
        
        <section epub:type="frontmatter" id="nlb-level1-lydbokavtalen">
            <xsl:if test="not(upper-case($library) = 'STATPED')">
                <h1>
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>The audiobook agreement</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Lydbokavtalen</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </h1>
            </xsl:if>

            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <p>
                        <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                        <xsl:text>This edition is produced by </xsl:text>
                        <xsl:value-of select="$library"/>
                        <xsl:text> in </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text>
                            pursuant to article 55
                            of the Norwegian Copyright Act and can be reproduced for private use only.
                            This copy is not to be redistributed. All digital copies are to be destroyed or returned to the publisher
                            by the end of the borrowing period. The copy will be marked so that it will be possible to trace it
                            to the borrower if misused. Violation of these terms of agreement may lead to liability according to
                            the Copyright Act. Such actions may also result in loss of the right to borrow accessible literature.
                        </xsl:text>
                    </p>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <p>
                        <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                        <xsl:text>Denne utgåva er produsert av </xsl:text>
                        <xsl:value-of select="$library"/>
                        <xsl:text> i </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text>
                              med heimel i åndsverklova § 55,
                              og kan berre kopierast til privat bruk. Eksemplaret kan ikkje distribuerast vidare. Når låneperioden er over,
                              skal alle digitale eksemplar destruerast eller returnerast til produsenten. Eksemplaret er merka slik
                              at det kan sporast tilbake til deg som lånar ved misbruk. Brot på desse avtalevilkåra kan medføre ansvar
                              etter åndsverklova. Slike handlingar kan også medføre tap av retten til å låne tilrettelagde bøker.</xsl:text>
                    </p>
                </xsl:when>
                <xsl:otherwise>
                    <p>
                        <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                        <xsl:text>Denne utgaven er produsert av </xsl:text>
                        <xsl:value-of select="$library"/>
                        <xsl:text> i </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text>
                            med hjemmel i åndsverklovens §55, og kan kun kopieres til privat bruk.
                            Eksemplaret kan ikke videredistribueres. Ved låneperiodens utløp skal alle digitale eksemplar destrueres eller returneres til produsenten. 
                            Eksemplaret er merket slik at det kan spores tilbake til deg som låntaker ved misbruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller medvirkning til slik ulovlig kopiering, kan medføre ansvar etter åndsverkloven. 
                            Slike handlinger kan også medføre tap av retten til å låne tilrettelagte lydbøker.</xsl:text>
                    </p>
                </xsl:otherwise>
            </xsl:choose>
        </section>

    </xsl:template>

    <xsl:template name="info-om-boka">
        <!-- Analyserer struktur -->
        <xsl:variable name="STRUKTUR.level1" as="element()*" select="//body/section[contains(@epub:type, 'bodymatter')]"/>
        <xsl:variable name="STRUKTUR.level1.typer" as="xs:string*" select="distinct-values(for $e in $STRUKTUR.level1 return normalize-space(substring-after($e/@epub:type, 'bodymatter')))"/>
        <xsl:variable name="STRUKTUR.level2" as="element()*" select="//body/section[contains(@epub:type, 'bodymatter')]/section"/>
        <xsl:variable name="STRUKTUR.level3" as="element()*" select="//body/section[contains(@epub:type, 'bodymatter')]/section/section"/>
        <xsl:variable name="STRUKTUR.har-sidetall" as="xs:boolean" select="count(//*[@epub:type eq 'pagebreak']) gt 1"/>
        <xsl:variable name="STRUKTUR.dybde" as="xs:integer" select="max(for $e in //section return count($e/ancestor-or-self::section))"/>
        
        <section epub:type="frontmatter" id="nlb-level1-om-boka">
            <h1>
                <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>About the book</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Om boka</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </h1>

            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:if
                        test="
                            fnk:metadata-finnes('dc:publisher.original') and
                            fnk:metadata-finnes('dc:publisher.location.original') and
                            fnk:metadata-finnes('dc:date.issued.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>The book is published by </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.original', true(), false())"/>
                            <xsl:text>, </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.location.original', true(), false())"/>
                            <xsl:text>, in </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:choose>
                                <xsl:when test="$STRUKTUR.har-sidetall">
                                    <xsl:text>, and has </xsl:text>
                                    <xsl:value-of
                                        select="//*[@epub:type eq 'pagebreak'][not(following::*[@epub:type eq 'pagebreak'])]/@title"/>
                                    <xsl:text> pages.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>The book was first published in </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:text>, this is the </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('bookEdition.original', true(), false())"/>
                            <xsl:text>. edition.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if test="$boken.er-oversatt">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>The book was first published in </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()), 'en')"/>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:title.original')">
                                <xsl:text> The original title is </xsl:text>
                                <em>
                                    <xsl:value-of
                                        select="fnk:hent-metadata-verdi('dc:title.original', true(), false())"
                                    />
                                </em>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:contributor.translator')">
                                <xsl:text> The book was translated by </xsl:text>
                                <xsl:value-of
                                    select="fnk:hent-metadata-verdi('dc:contributor.translator', false(), true())"/>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                        </p>
                    </xsl:if>
                    
                    <xsl:if test="count($STRUKTUR.level1.typer) eq 1">
                        <!-- Vi forutsetter at det bare er én type på nivå 1
                    20171018-psps: Sjekke om det er greit
                    Bør vi gjøre noe hvis det ikke er tilfelle.
                -->
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:choose>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2 and $STRUKTUR.level3">
                                    <!-- Tre nivåer, første nivå er deler -->
                                            <xsl:text>The book consists of </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> parts and </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level2)"/>
                                            <xsl:text> chapters with subheadings.</xsl:text>

                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2">
                                    <!-- To nivåer, første nivå er deler -->
                                            <xsl:text>The book consists of </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> parts and </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level2)"/>
                                            <xsl:text> chapters.</xsl:text>
                                    
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part')">
                                    <!-- Bare ett nivå, første nivå er deler -->
                                            <xsl:text>The book consists of </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> parts.</xsl:text>
                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter') and $STRUKTUR.level2">
                                    <!-- To (eller flere) nivåer, første nivå er kapitler -->
                                            <xsl:text>The book consists of </xsl:text>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> chapters with subheadings.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter')">
                                    <!-- Bare ett nivå, første nivå er kapitler -->
                                            <xsl:text>The book consists of </xsl:text>
                                            <xsl:choose>
                                                <xsl:when test="count($STRUKTUR.level1) eq 1">
                                                    <xsl:text>one chapter.</xsl:text>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                                    <xsl:text> chapters .</xsl:text>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                            <xsl:text>The book is not divided into chapters, but is made up of sections of variable length.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    
                    <p>
                        <xsl:text>This is an audiobook with text. </xsl:text>
                        <xsl:text>It is possible to search for words in the text. </xsl:text>
                        <xsl:text>It is possible to navigate the audiobook by </xsl:text>
                        <xsl:choose>
                            <xsl:when test="$STRUKTUR.dybde eq 1">
                                <xsl:text> one heading level.</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of
                                    select="fnk:tall-til-tallord($STRUKTUR.dybde, false(), false())"/>
                                <xsl:text> heading levels</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:if test="$STRUKTUR.har-sidetall">
                            <xsl:text> and by page numbers</xsl:text>
                        </xsl:if>
                        <xsl:text>.</xsl:text>
                    </p>

                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:if
                        test="
                            fnk:metadata-finnes('dc:publisher.original') and
                            fnk:metadata-finnes('dc:publisher.location.original') and
                            fnk:metadata-finnes('dc:date.issued.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>Boka er utgjeven av </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.original', true(), false())"/>
                            <xsl:text>, </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.location.original', true(), false())"/>
                            <xsl:text>, i </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:choose>
                                <xsl:when test="$STRUKTUR.har-sidetall">
                                    <xsl:text>, og er på </xsl:text>
                                    <xsl:value-of
                                        select="//*[@epub:type eq 'pagebreak'][not(following::*[@epub:type eq 'pagebreak'])]/@title"/>
                                    <xsl:text> sider.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>Boka er første gang utgjeven  i </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:text>, dette er </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('bookEdition.original', true(), false())"/>
                            <xsl:text>. utgåva.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if test="$boken.er-oversatt">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>Boka er første gong utgjeven på </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()), 'nn')"/>
                                <xsl:text>. </xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:title.original')">
                                <xsl:text> Originaltittel er </xsl:text>
                                <em>
                                    <xsl:value-of
                                        select="fnk:hent-metadata-verdi('dc:title.original', true(), false())"
                                    />
                                </em>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:contributor.translator')">
                                <xsl:text> Boka er omsett av </xsl:text>
                                <xsl:value-of
                                    select="fnk:hent-metadata-verdi('dc:contributor.translator', false(), true())"/>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                        </p>
                    </xsl:if>
                    
                    <xsl:if test="count($STRUKTUR.level1.typer) eq 1">
                        <!-- Vi forutsetter at det bare er én type på nivå 1
                    20171018-psps: Sjekke om det er greit
                    Bør vi gjøre noe hvis det ikke er tilfelle.
                -->
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:choose>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2 and $STRUKTUR.level3">
                                    <!-- Tre nivåer, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapittel med underkapittel.</xsl:text>
                                    
                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2">
                                    <!-- To nivåer, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> underkapittel.</xsl:text>
                                    
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part')">
                                    <!-- Bare ett nivå, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler.</xsl:text>
                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter') and $STRUKTUR.level2">
                                    <!-- To (eller flere) nivåer, første nivå er kapitler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> kapittel med underkapittel.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter')">
                                    <!-- Bare ett nivå, første nivå er kapitler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:choose>
                                        <xsl:when test="count($STRUKTUR.level1) eq 1">
                                            <xsl:text>ett kapittel.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> kapitler.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka er ikkje delt inn i kapittel, men består av lengre og kortare avsnitt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>

                    <p>
                        <xsl:text>Dette er ei lydbok med tekst. </xsl:text>
                        <xsl:text>Det er mogleg å søke på ord i teksten. </xsl:text>
                        <xsl:text>Det er mogleg å navigere i lydboka på </xsl:text>
                        <xsl:value-of
                            select="fnk:tall-til-tallord($STRUKTUR.dybde, true(), false())"/>
                        <xsl:text> overskriftsnivå</xsl:text>
                        <xsl:if test="$STRUKTUR.har-sidetall">
                            <xsl:text> og på sidetal</xsl:text>
                        </xsl:if>
                        <xsl:text>.</xsl:text>
                    </p>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if
                        test="
                            fnk:metadata-finnes('dc:publisher.original') and
                            fnk:metadata-finnes('dc:publisher.location.original') and
                            fnk:metadata-finnes('dc:date.issued.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>Boka er utgitt av </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.original', true(), false())"/>
                            <xsl:text>, </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:publisher.location.original', true(), false())"/>
                            <xsl:text>, i </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:choose>
                                <xsl:when test="$STRUKTUR.har-sidetall">
                                    <xsl:text>, og er på </xsl:text>
                                    <xsl:value-of
                                        select="//*[@epub:type eq 'pagebreak'][not(following::*[@epub:type eq 'pagebreak'])]/@title"/>
                                    <xsl:text> sider.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:text>Boka er første gang utgitt i  </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('dc:date.issued.original', true(), false())"/>
                            <xsl:text>, dette er </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('bookEdition.original', true(), false())"/>
                            <xsl:text>. utgave.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if test="$boken.er-oversatt">
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>Boka er første gang utgitt på </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()), 'nb')"/>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:title.original')">
                                <xsl:text> Originaltittel er </xsl:text>
                                <em>
                                    <xsl:value-of
                                        select="fnk:hent-metadata-verdi('dc:title.original', true(), false())"
                                    />
                                </em>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                            <xsl:if test="fnk:metadata-finnes('dc:contributor.translator')">
                                <xsl:text> Boka er oversatt av </xsl:text>
                                <xsl:value-of
                                    select="fnk:hent-metadata-verdi('dc:contributor.translator', false(), true())"/>
                                <xsl:text>.</xsl:text>
                            </xsl:if>
                        </p>
                    </xsl:if>
                    <xsl:if test="count($STRUKTUR.level1.typer) eq 1">
                        <!-- Vi forutsetter at det bare er én type på nivå 1
                    20171018-psps: Sjekke om det er greit
                    Bør vi gjøre noe hvis det ikke er tilfelle.
                -->
                        <p>
                            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                            <xsl:choose>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2 and $STRUKTUR.level3">
                                    <!-- Tre nivåer, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapitler med underkapitler.</xsl:text>
                                    
                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2">
                                    <!-- To nivåer, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> underkapitler.</xsl:text>
                                    
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part')">
                                    <!-- Bare ett nivå, første nivå er deler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler.</xsl:text>
                                </xsl:when>
                                <xsl:when
                                    test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter') and $STRUKTUR.level2">
                                    <!-- To (eller flere) nivåer, første nivå er kapitler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> kapitler med underkapitler.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter')">
                                    <!-- Bare ett nivå, første nivå er kapitler -->
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:choose>
                                        <xsl:when test="count($STRUKTUR.level1) eq 1">
                                            <xsl:text>ett kapittel.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="count($STRUKTUR.level1)"/>
                                            <xsl:text> kapitler.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka er ikke delt inn i kapitler, men består av lengre og kortere avsnitt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <p>
                        <xsl:text>Dette er en lydbok med tekst. </xsl:text>
                        <xsl:text>Det er mulig å søke på ord i teksten. </xsl:text>
                        <xsl:text>Det er mulig å navigere i lydboka på </xsl:text>
                        <xsl:value-of
                            select="fnk:tall-til-tallord($STRUKTUR.dybde, true(), false())"/>
                        <xsl:choose>
                            <xsl:when test="$STRUKTUR.dybde eq 1">
                                <xsl:text> overskriftsnivå</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text> overskriftsnivåer</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:if test="$STRUKTUR.har-sidetall">
                            <xsl:text> og på sidetall</xsl:text>
                        </xsl:if>
                        <xsl:text>.</xsl:text>
                    </p>
                </xsl:otherwise>
            </xsl:choose>
        </section>
    </xsl:template>


</xsl:stylesheet>
