<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 04.04.2018
    -->

    <!--
        Håndterer lister:
        
        ** Lydbøker behandles på samme måte, uavhengig om de skal leses inn manuelt eller med TTS.

        ** For en rotliste (det vil si en liste som ikke er underliste til en annen liste):
               ** Annonseres i forkant med følgende informasjon: "Her følger en liste med [x] punkter."
               ** Dersom minst ett av listepunktene har underpunkter, så legger vi til følgende informasjon: "[y] av disse punktene har underpunkter."
               ** Annonseringen legges inn som et p-element, med class="nlb-ekstra-informasjon", umiddelbart før listen.

               ** For hvert listepunkt legges det inn følgende tekst li-elementet, før den eksisterende teksten: "[n]. punkt: ".
               ** Dersom ALLE listepunkter er slik at tekstinnholdet begynner med ett eller flere sifre, etterfulgt av punktum, kolon, sluttparentes eller mellomrom, skal det istedenfor legges inn "Første punkt: ", "Neste punkt: ", ... "Neste punkt" og "Siste punkt: "
               ** Slik tekst skal plasseres i et span-element, med class="nlb-ekstra-informasjon". (Eller i et p-element, se kommentar i template for li-elementet)

               ** Listen utannonseres med teksten "Liste slutt", plassert i et p-element, med class="nlb-ekstra-informasjon", umiddelbart etter listen.

        ** For alle andre lister (og det blir altså lister med underpunkter til en overordnet liste): 
               ** Samme som rotlister, med følgende unntak:
               ** Annonseres i forkant med følgende informasjon: "Her følger en liste med [x] underpunkter."

               ** Listen utannonseres med teksten "Underpunkter slutt", plassert i et p-element, med class="nlb-ekstra-informasjon", umiddelbart etter listen.

    -->

    <xsl:template
        match="
            ol[not(some $a in ancestor::element()
            satisfies fnk:epub-type($a/@epub:type, 'toc')) and not(some $li in li satisfies ($li/@class eq 'notebody' or fnk:epub-type($li/@epub:type,'footnote')))]">

        <xsl:variable name="er-rotliste" as="xs:boolean" select="not(exists(ancestor::ol))"/>
        <xsl:variable name="listepunkter-er-numeriske" as="xs:boolean"
            select="
                every $li in li
                    satisfies matches(normalize-space($li), '^(\d+\s|\d+(\.|\)|:)\s)')"/>
        <xsl:variable name="antall-punkter-med-underpunkt" as="xs:integer"
            select="count(li[descendant::ol])"/>

        <!-- Legg inn et p-element før listen -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:text>Here is a list with </xsl:text>
                    <xsl:choose>
                        <xsl:when test="count(li) eq 1">
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text>one bullet point.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>one sub-bullet.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="count(li)"/>
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text> bullet points.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text> sub-bullets.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="$antall-punkter-med-underpunkt gt 0">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="$antall-punkter-med-underpunkt"/>
                        <xsl:text> of these bullet points have sub-bullets.</xsl:text>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:text>Her følgjer ei liste med </xsl:text>
                    <xsl:choose>
                        <xsl:when test="count(li) eq 1">
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text>eit punkt.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>eit underpunkt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="count(li)"/>
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text> punkt.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text> underpunkt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="$antall-punkter-med-underpunkt gt 0">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="$antall-punkter-med-underpunkt"/>
                        <xsl:text> av desse punkta har underpunkt.</xsl:text>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Her følger en liste med </xsl:text>
                    <xsl:choose>
                        <xsl:when test="count(li) eq 1">
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text>ett punkt.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>ett underpunkt.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="fnk:tall-til-tallord(count(li), true(), false())"/>
                            <xsl:choose>
                                <xsl:when test="$er-rotliste">
                                    <xsl:text> punkter.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text> underpunkter.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="$antall-punkter-med-underpunkt gt 0">
                        <xsl:text> </xsl:text>
                        <xsl:value-of
                            select="fnk:lag-stor-førstebokstav(fnk:tall-til-tallord($antall-punkter-med-underpunkt, true(), false()))"/>
                        <xsl:text> av disse punktene har underpunkter.</xsl:text>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </p>

        <!-- Så kommer selve listen -->
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@* except @class except @style"/>
            <xsl:attribute name="class" select="'list-style-type-none'"/>
            <xsl:attribute name="style" select="'list-style-type: none;'"/>
            <xsl:apply-templates>
                <xsl:with-param name="listens-listepunkter-er-numeriske" as="xs:boolean"
                    select="$listepunkter-er-numeriske" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>

        <!-- Og til slutt et p-element for å informere om at listen er slutt -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:choose>
                        <xsl:when test="$er-rotliste">
                            <xsl:text>End of list</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>End of sub-bullets</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:choose>
                        <xsl:when test="$er-rotliste">
                            <xsl:text>Liste slutt</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Underpunkt slutt</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="$er-rotliste">
                            <xsl:text>Liste slutt</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Underpunkter slutt</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </p>
    </xsl:template>

    <xsl:template match="li[not(@class eq 'notebody' or fnk:epub-type(@epub:type,'footnote'))]">
        <xsl:param name="listens-listepunkter-er-numeriske" as="xs:boolean" select="false()"
            tunnel="yes"/>

        <xsl:variable name="er-første-punkt" as="xs:boolean"
            select="not(exists(preceding-sibling::li))"/>
        <xsl:variable name="er-siste-punkt" as="xs:boolean"
            select="not(exists(following-sibling::li))"/>
        <xsl:variable name="listepunktets-posisjon" as="xs:integer"
            select="count(preceding-sibling::li) + 1"/>
        <xsl:variable name="tekst" as="xs:string">
            <xsl:choose>
                <xsl:when test="$listens-listepunkter-er-numeriske">
                    <xsl:choose>
                        <xsl:when test="$er-første-punkt and $er-siste-punkt">
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>First and only bullet point: </xsl:text>
                                </xsl:when>
                                <xsl:when test="$SPRÅK.nn">
                                    <xsl:text>Første og einaste punkt: </xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Første og eneste punkt: </xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$er-første-punkt">
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>First bullet point: </xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Første punkt: </xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$er-siste-punkt">
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>Last bullet point: </xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Siste punkt: </xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:choose>
                                <xsl:when test="$SPRÅK.en">
                                    <xsl:text>Next bullet point: </xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>Neste punkt: </xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <!--
                        20180423: Endret fra "n. punkt: " til "Punkt n: "
                    -->
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:value-of
                                select="concat('Bullet point ',$listepunktets-posisjon, ': ')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat('Punkt ',$listepunktets-posisjon, ': ')"/>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>

            <!-- Legg inn det ekstra elementet med informasjon -->
            <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                <xsl:with-param name="informasjon" as="xs:string" select="$tekst"/>
            </xsl:call-template>

            <!-- Og prosesser innholdet i listen på vanlig måte -->
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
