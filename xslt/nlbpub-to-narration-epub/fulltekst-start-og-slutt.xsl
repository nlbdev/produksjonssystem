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
        <xsl:call-template name="generer-tittel"/>
        <!-- PSPS: Alltid før cover,sier Roald -->
        <xsl:call-template name="lydbokavtalen"/>
        <xsl:call-template name="info-om-boka"/>
        <xsl:call-template name="info-om-den-tilrettelagte-utgaven"/>
    </xsl:template>

    <xsl:template name="generer-tittel">
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
        </section>
    </xsl:template>

    <xsl:template name="generer-sluttinformasjon">
        <hr class="separator"/>
        <p>
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
    </xsl:template>

    <xsl:template name="lydbokavtalen">
        <section epub:type="frontmatter" id="nlb-level1-lydbokavtalen">
            <h1>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>The audiobook agreement</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Lydbokavtalen</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </h1>

            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <p>
                        <xsl:text>This edition is produced by NLB in </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text> pursuant to article 17a of the Norwegian Copyright Act and can be reproduced for private use only. 
                            This copy is not to be redistributed. 
                            All digital copies are to be destroyed or returned to the publisher by the end of the borrowing period. 
                            The copy will be marked so that it will be possible to trace it to the borrower if misused.</xsl:text>
                    </p>
                    <p>
                        <xsl:text>Violation of these terms of agreement may lead to liability according to the Copyright Act. 
                            Such actions may also result in loss of the right to borrow accessible literature.</xsl:text>
                    </p>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <p>
                        <xsl:text>Denne utgåva er produsert av NLB i </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text> med heimel i åndsverklova § 17a, og kan bare kopierast til privat bruk. Eksemplaret kan ikkje distribuerast vidare. Når låneperioden er over skal
                        alle digitale eksemplar destruerast eller returnerast til produsenten.
                        Eksemplaret er merka slik at det kan sporast tilbake til deg som lånar ved
                        misbruk.</xsl:text>
                    </p>
                    <p>
                        <xsl:text>Brot på desse avtalevilkåra kan medføre ansvar etter åndsverklova.
                        Slike handlingar kan også medføre tap av retten til å låne tilrettelagde
                        lydbøker.</xsl:text>
                    </p>
                </xsl:when>
                <xsl:otherwise>
                    <p>
                        <xsl:text>Denne utgaven er produsert av NLB i </xsl:text>
                        <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                        <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                        <xsl:text> med hjemmel i åndsverklovens § 17a, og kan kun kopieres til privat bruk. 
                            Eksemplaret kan ikke videredistribueres. Ved låneperiodens utløp skal alle digitale eksemplar 
                            destrueres eller returneres til produsenten. Eksemplaret er merket slik at det kan spores tilbake 
                            til deg som låner ved misbruk.</xsl:text>
                    </p>
                    <p>
                        <xsl:text>Brudd på disse avtalevilkårene kan medføre ansvar etter åndsverkloven. 
                            Slike handlinger kan også medføre tap av retten til å låne tilrettelagte lydbøker.</xsl:text>
                    </p>
                </xsl:otherwise>
            </xsl:choose>
        </section>

    </xsl:template>

    <xsl:template name="info-om-boka">
        <section epub:type="frontmatter" id="nlb-level1-om-boka">
            <h1>
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
                                    <xsl:text>. There are no pages in this book.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if test="fnk:metadata-finnes('schema:isbn')">
                        <p>
                            <xsl:text>The original ISBN is </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('schema:isbn', true(), false())"/>
                            <xsl:text>.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
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
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>The book was first published in </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()),'en')"/>
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

                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:if
                        test="
                            fnk:metadata-finnes('dc:publisher.original') and
                            fnk:metadata-finnes('dc:publisher.location.original') and
                            fnk:metadata-finnes('dc:date.issued.original')">
                        <p>
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
                                    <xsl:text>. Boka inneheld ikkje sidetal.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if test="fnk:metadata-finnes('schema:isbn')">
                        <p>
                            <xsl:text>ISBN-nummeret til originalen er  </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('schema:isbn', true(), false())"/>
                            <xsl:text>.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
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
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>Boka er første gong utgjeven på </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()),'nn')"/>
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
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if
                        test="
                            fnk:metadata-finnes('dc:publisher.original') and
                            fnk:metadata-finnes('dc:publisher.location.original') and
                            fnk:metadata-finnes('dc:date.issued.original')">
                        <p>
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
                                    <xsl:text>. Boka inneholder ikke sidetall.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </p>
                    </xsl:if>
                    <xsl:if test="fnk:metadata-finnes('schema:isbn')">
                        <p>
                            <xsl:text>Originalens ISBN er </xsl:text>
                            <xsl:value-of
                                select="fnk:hent-metadata-verdi('schema:isbn', true(), false())"/>
                            <xsl:text>.</xsl:text>
                        </p>
                    </xsl:if>
                    <xsl:if
                        test="fnk:metadata-finnes('dc:date.issued.original') and fnk:metadata-finnes('bookEdition.original')">
                        <p>
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
                            <xsl:if test="fnk:metadata-finnes('dc:language.original')">
                                <xsl:text>Boka er første gang utgitt på </xsl:text>
                                <xsl:value-of
                                    select="fnk:språkkode-til-tekst(fnk:hent-metadata-verdi('dc:language.original', true(), false()),'nb')"/>
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
                </xsl:otherwise>
            </xsl:choose>

            <xsl:if test="count($STRUKTUR.level1.typer) eq 1">
                <!-- Vi forutsetter at det bare er én type på nivå 1
                    20171018-psps: Sjekke om det er greit
                    Bør vi gjøre noe hvis det ikke er tilfelle.
                -->
                <p>

                    <xsl:choose>
                        <xsl:when
                            test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2 and $STRUKTUR.level3">
                            <!-- Tre nivåer, første nivå er deler -->
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>The book consists of </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> parts and </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> chapters with subheadings.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler  og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapittel med underkapittel.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler  og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapitler med underkapitler.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when
                            test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part') and $STRUKTUR.level2">
                            <!-- To nivåer, første nivå er deler -->
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>The book consists of </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> parts and </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> chapters.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler  og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapittel.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler  og </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level2)"/>
                                    <xsl:text> kapitler.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>

                        </xsl:when>
                        <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'part')">
                            <!-- Bare ett nivå, første nivå er deler -->
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>The book consists of </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> parts.</xsl:text>
                                </xsl:when>
                                <!-- Samme tekst for nynorsk og bokmål -->
                                <xsl:otherwise>
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> deler.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when
                            test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter') and $STRUKTUR.level2">
                            <!-- To (eller flere) nivåer, første nivå er kapitler -->
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>The book consists of </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> chapters with subheadings.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> kapittel  med underkapittel.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of select="count($STRUKTUR.level1)"/>
                                    <xsl:text> kapitler  med underkapitler.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$STRUKTUR.level1 and ($STRUKTUR.level1.typer eq 'chapter')">
                            <!-- Bare ett nivå, første nivå er kapitler -->
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
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
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Boka består av </xsl:text>
                                    <xsl:value-of
                                        select="fnk:tall-til-tallord(count($STRUKTUR.level1), true(), false())"/>
                                    <xsl:text> kapittel.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
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
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>The book is not divided into chapters, but is made up of sections of variable length.</xsl:text>
                                </xsl:when>
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Boka er ikkje delt inn i kapittel, men består av lengre og kortare avsnitt.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Boka er ikke delt inn i kapitler, men består av lengre og kortere avsnitt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>

                        </xsl:otherwise>
                    </xsl:choose>
                </p>
            </xsl:if>
        </section>
    </xsl:template>

    <xsl:template name="info-om-den-tilrettelagte-utgaven">
        <section epub:type="frontmatter" id="nlb-level1-om-lydboka">
            <h1>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">About the accessible edition</xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:text>Om den tilrettelagde utgåva</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Om den tilrettelagte utgaven</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </h1>
            <p>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:text>This edition contains synchronised text and audio.
                            It is possible to listen to the audiobook while the text is displayed on a screen.</xsl:text>
                    </xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:text>Denne tilrettelagde utgåva inneheld tekst og lyd som er synkronisert, 
                            det vil seie at det er [muleg|mogleg] å spele av lydboka samtidig som teksten kan visast på ein skjerm. </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Denne tilrettelagte utgaven inneholder tekst og lyd som er synkronisert, 
                            det vil si at det er mulig å spille av lydboka samtidig som teksten vises på en skjerm. </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </p>
            <p>
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
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
                    </xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:text>Det er muleg å navigere i lydboka på </xsl:text>
                        <xsl:value-of
                            select="fnk:tall-til-tallord($STRUKTUR.dybde, true(), false())"/>
                        <xsl:text> overskriftsnivå</xsl:text>
                        <xsl:if test="$STRUKTUR.har-sidetall">
                            <xsl:text> og på sidetal</xsl:text>
                        </xsl:if>
                        <xsl:text>.</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>Det er mulig å navigere i lydboka på </xsl:text>
                        <xsl:value-of
                            select="fnk:tall-til-tallord($STRUKTUR.dybde, true(), false())"/>
                        <xsl:text> overskriftsnivå</xsl:text>
                        <xsl:if test="$STRUKTUR.har-sidetall">
                            <xsl:text> og på sidetall</xsl:text>
                        </xsl:if>
                        <xsl:text>.</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </p>
        </section>
    </xsl:template>


</xsl:stylesheet>
