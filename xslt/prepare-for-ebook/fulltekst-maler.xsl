<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">
    
    <!-- language code is one of se, nn, en or nb (default: nb)-->
    <xsl:variable name="language" select="/*:html/*:head/*:meta[@name eq 'dc:language'][1]/(
                                            if (lower-case(@content) = ('sme', 'se')) then 'se'
                                            else if (lower-case(@content) = ('nn-no', 'nn')) then 'nn'
                                            else if (lower-case(@content) = 'en') then 'en'
                                            else 'nb')"/>
    
    <xsl:variable name="publisher-original" select="/*:html/*:head/*:meta[@name eq 'dc:publisher.original'][1]/@content" as="xs:string?"/>
    <xsl:variable name="publisher-location-original" select="/*:html/*:head/*:meta[@name eq 'dc:publisher.location.original'][1]/@content" as="xs:string?"/>
    <xsl:variable name="date-issued-original" select="/*:html/*:head/*:meta[@name eq 'dc:date.issued.original'][1]/@content" as="xs:string?"/>
    <xsl:variable name="has-publisher-metadata" select="exists($publisher-original) and exists($publisher-location-original) and exists($date-issued-original)" as="xs:boolean"/>

    <xsl:variable name="page-count" select="(/*:html/*:body/*:section[tokenize(@epub:type,'\s+')='bodymatter']//*[tokenize(@epub:type,'\s+') = 'pagebreak'])[last()]/(@title, text())[1]" as="xs:string?"/>

    <xsl:variable name="library" select="/*:html/*:head/*:meta[@name eq 'schema:library'][1]/@content" as="xs:string?"/>

    <xsl:template name="copyright-page">
        <xsl:choose>
            <xsl:when test="upper-case($library) = 'STATPED'">
                <!-- Statped vil ikke ha "Opphavsrett" -->
            </xsl:when>
            <xsl:otherwise>
                <!-- Alle andre bøker skal ha "Opphavsrett" -->
                <section epub:type="frontmatter" id="nlb-level1-opphavsrett">
                    <xsl:if test="not(upper-case($library) = 'STATPED')">
                        <h1 class="nlb-ekstra-informasjon">
                            <xsl:choose>
                                <xsl:when test="$language = 'en'">
                                    <xsl:text>The audiobook agreement</xsl:text>
                                </xsl:when>
                                <xsl:when test="$language = 'se'">
                                    <xsl:text>Jietnagirjesoahpamuš</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Lydbokavtalen</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </h1>
                    </xsl:if>

                    <xsl:choose>
                        <xsl:when test="$language = 'en'">
                            <p class="nlb-ekstra-informasjon">
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
                        <xsl:when test="$language = 'nn'">
                            <p class="nlb-ekstra-informasjon">
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
                        <xsl:when test="$language = 'se'">
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Dán veršuvdna lea </xsl:text>
                                <xsl:value-of select="$library"/>
                                <xsl:text> buvttadan jagi </xsl:text>
                                <!-- psps-20171017: Kanskje raffinere årstallet under litt mer... -->
                                <xsl:value-of select="format-date(current-date(), '[Y]')"/>
                                <xsl:text>
                                        vuoigŋaduodjelága § 55 mielde, ja dan oažžu dušše fal priváhta
                                        atnui máŋget. Ii leat lohpi dán gahppala juohkit viiddaseabbot. Luoikkahanáigodaga loahpas galget buot
                                        digitála gáhppálagat duššaduvvot dahje máhcahuvvot buvttadeaddjái. Gahppal lea merkejuvvon nu, ahte dan
                                        sáhttá guorrat dutnje luoikkaheaddjái jus vearrut adnojuvvo. Dáid sohpamušeavttuid rihkkun sáhttá
                                        mielddisbuktit ovddasvástádusa vuoigŋaduodjelága mielde. Dakkár dagut sáhttet maid mielddisbuktit ahte
                                        vuoigatvuohta luoikkahit heivehuvvon jietnagirjjiid manahuvvo.</xsl:text>
                            </p>
                        </xsl:when>
                        <xsl:otherwise>
                            <p class="nlb-ekstra-informasjon">
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
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="info-om-boka">
        <xsl:choose>
            <xsl:when test="upper-case($library) = 'STATPED'">
                <!-- Statped vil ikke ha "Om boka" -->
            </xsl:when>
            <xsl:otherwise>
                <!-- Alle andre bøker skal ha "Om boka" -->
                <xsl:variable name="top-level-section-count" as="xs:integer" select="count(//body/section[tokenize(@epub:type, '\s+') = 'bodymatter' and not(tokenize(@epub:type, '\s+') = 'part')] | //body/section[tokenize(@epub:type, '\s+') = 'bodymatter' and tokenize(@epub:type, '\s+') = 'part']/section)"/>
                <xsl:variable name="section-depth" as="xs:integer" select="max(for $e in //section return count($e/ancestor-or-self::section))"/>

                <section epub:type="frontmatter" id="nlb-level1-om-boka">
                    <h1 class="nlb-ekstra-informasjon">
                        <xsl:choose>
                            <xsl:when test="$language = 'en'">
                                <xsl:text>About the book</xsl:text>
                            </xsl:when>
                            <xsl:when test="$language = 'se'">
                                <xsl:text>Girjji birra</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>Om boka</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </h1>

                    <xsl:choose>
                        <xsl:when test="$language = 'en'">
                            <xsl:if test="$has-publisher-metadata">
                                <p class="nlb-ekstra-informasjon">
                                    <xsl:text>This book is published by </xsl:text>
                                    <xsl:value-of select="$publisher-original"/>
                                    <xsl:text>, </xsl:text>
                                    <xsl:value-of select="$publisher-location-original"/>
                                    <xsl:text>, in </xsl:text>
                                    <xsl:value-of select="$date-issued-original"/>
                                    <xsl:choose>
                                        <xsl:when test="exists($page-count)">
                                            <xsl:text> and has </xsl:text>
                                            <xsl:value-of select="$page-count"/>
                                            <xsl:text> pages.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:text>.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </p>
                            </xsl:if>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>It consists of </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($top-level-section-count)"/>
                                <xsl:choose>
                                    <xsl:when test="$top-level-section-count eq 1">
                                        <xsl:text> chapter.</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text> chapters.</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>The book has headings on </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($section-depth)"/>
                                <xsl:choose>
                                    <xsl:when test="$section-depth eq 1">
                                        <xsl:text> level</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text> levels</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xsl:text> and it is possible to navigate the text and search for words.</xsl:text>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Please note that the adapted version may differ from the original.</xsl:text>
                            </p>
                        </xsl:when>
                        <xsl:when test="$language = 'nn'">
                            <xsl:if
                                test="
                                    $has-publisher-metadata">
                                <p class="nlb-ekstra-informasjon">
                                    <xsl:text>Boka er utgjeve av </xsl:text>
                                    <xsl:value-of select="$publisher-original"/>
                                    <xsl:text>, </xsl:text>
                                    <xsl:value-of select="$publisher-location-original"/>
                                    <xsl:text>, i </xsl:text>
                                    <xsl:value-of select="$date-issued-original"/>
                                    <xsl:choose>
                                        <xsl:when test="exists($page-count)">
                                            <xsl:text> og er på </xsl:text>
                                            <xsl:value-of select="$page-count"/>
                                            <xsl:text> sider.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:text>.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </p>
                            </xsl:if>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Den består av </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($top-level-section-count)"/>
                                <xsl:text> kapittel.</xsl:text>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Boka har overskrifter på </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($section-depth)"/>
                                <xsl:text> nivå</xsl:text>
                                <xsl:text>, og du kan navigere i teksten og søke på ord.</xsl:text>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Vi gjer merksam på at den tilrettelagde utgåva kan avvika frå originalen.</xsl:text>
                            </p>
                        </xsl:when>
                        <xsl:when test="$language = 'se'">
                            <xsl:if
                                test="
                                    $has-publisher-metadata">
                                <p class="nlb-ekstra-informasjon">
                                    <xsl:text>Girjji lea almmuhan </xsl:text>
                                    <xsl:value-of select="$publisher-original"/>
                                    <xsl:text>, </xsl:text>
                                    <xsl:value-of select="$publisher-location-original"/>
                                    <xsl:text>, </xsl:text>
                                    <xsl:value-of select="$date-issued-original"/>
                                    <xsl:text>:s</xsl:text>
                                    <xsl:choose>
                                        <xsl:when test="exists($page-count)">
                                            <xsl:text> ja lea </xsl:text>
                                            <xsl:value-of select="$page-count"/>
                                            <xsl:text> siiddut.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:text>.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </p>
                            </xsl:if>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Girjjis leat </xsl:text>
                                <xsl:choose>
                                    <xsl:when test="$top-level-section-count eq 1">
                                        <xsl:text>okta kapihtal.</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="fnk:tall-til-tallord($top-level-section-count)"/>
                                        <xsl:text> kapihttalat.</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Lea vejolaš navigeret jietnagirjjis okta </xsl:text>
                                <xsl:value-of
                                    select="fnk:tall-til-tallord($section-depth)"/>
                                <xsl:text> bajilčáladási siskkobealde. </xsl:text>
                                <xsl:text>Lea vejolaš ohcat sániid bokte teavsttas.</xsl:text>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Mii muitalit ahte oahppat váikkuha oahppat.</xsl:text>
                            </p>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:if
                                test="
                                    $has-publisher-metadata">
                                <p class="nlb-ekstra-informasjon">
                                    <xsl:text>Boka er utgitt av </xsl:text>
                                    <xsl:value-of select="$publisher-original"/>
                                    <xsl:text>, </xsl:text>
                                    <xsl:value-of select="$publisher-location-original"/>
                                    <xsl:text>, i </xsl:text>
                                    <xsl:value-of select="$date-issued-original"/>
                                    <xsl:choose>
                                        <xsl:when test="exists($page-count)">
                                            <xsl:text> og er på </xsl:text>
                                            <xsl:value-of select="$page-count"/>
                                            <xsl:text> sider.</xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:text>.</xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </p>
                            </xsl:if>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Den består av </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($top-level-section-count)"/>
                                <xsl:choose>
                                    <xsl:when test="$top-level-section-count eq 1">
                                        <xsl:text> kapittel.</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text> kapitler.</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Boka har overskrifter på </xsl:text>
                                <xsl:value-of select="fnk:tall-til-tallord($section-depth)"/>
                                <xsl:choose>
                                    <xsl:when test="$section-depth eq 1">
                                        <xsl:text> nivå</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text> nivåer</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xsl:text>, og du kan navigere i teksten og søke på ord.</xsl:text>
                            </p>
                            <p class="nlb-ekstra-informasjon">
                                <xsl:text>Vi gjør oppmerksom på at den tilrettelagte utgaven kan avvike fra originalen.</xsl:text>
                            </p>
                        </xsl:otherwise>
                    </xsl:choose>
                </section>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:function name="fnk:tall-til-tallord" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>

        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:choose>
                    <xsl:when test="$language = 'en'">
                        <xsl:value-of select="'one'"/>
                    </xsl:when>
                    <xsl:when test="$language = 'se'">
                        <xsl:value-of select="'okta'"/>
                    </xsl:when>
                    <xsl:when test="$language = 'nn'">
                        <xsl:value-of select="'eitt'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'ett'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$tall gt 15">
                <xsl:value-of select="$tall"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="tallord" as="xs:string+">
                    <xsl:choose>
                        <xsl:when test="$language = 'en'">
                            <xsl:sequence
                                select="
                                ('one', 'two', 'three', 'four', 'five', 'six', 'seven',
                                'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen')"
                            />
                        </xsl:when>
                        <xsl:when test="$language = 'se'">
                            <xsl:sequence
                                select="
                                ('okta', 'guokte', 'golbma', 'njeallje', 'vihtta', 'guhtta', 'čieža',
                                'gávcci', 'ovcci', 'logi', '11', '12', '13', '14', '15')"
                            />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence
                                select="
                                    ('en,ein,ei eller eitt', 'to', 'tre', 'fire', 'fem', 'seks', 'sju',
                                    'åtte', 'ni', 'ti', 'elleve', 'tolv', 'tretten', 'fjorten', 'femten'
                                    )"
                            />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:value-of select="$tallord[position() eq $tall]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
