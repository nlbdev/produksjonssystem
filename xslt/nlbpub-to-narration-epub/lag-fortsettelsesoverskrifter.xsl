<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Denne transformasjonen brukes på output fra transformasjonen basert på prepare-for-narration.xsl.
        
        Transformasjonen sjekker, på slutten av hver section, om det er behov for å legge inn en fortsettelsesoverskrift, og legger den inn hvis behovet er der.


        Per Sennels, 11.04.2018
    -->

    <xsl:include href="ekstra-informasjon.xsl"/>

    <xsl:output method="xhtml" indent="yes" include-content-type="no"/>

    <xsl:template match="/">
        <xsl:message>lag-fortsettelsesoverskrifter.xsl (0.9.2 / 2018-05-29)</xsl:message>
        <xsl:message>* Transformerer ... </xsl:message>
        <xsl:message>* Lager fortsettelsesoverskrifter ... </xsl:message>

        <xsl:apply-templates/>

        <xsl:message>
            <xsl:text>* Satt inn </xsl:text>
            <xsl:value-of
                select="count(//section/section[following-sibling::element() and not(local-name(following-sibling::element()[1]) eq 'section')])"/>
            <xsl:text> fortsettelsesoverskrifter</xsl:text>
        </xsl:message>
    </xsl:template>

    <xsl:template match="@* | node()" priority="-5" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>


    <xsl:template match="section/section">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>

        <!-- Sjekke om vi trenger en fortsettelsesoverskrift (FO) -->
        <xsl:if
            test="
                following-sibling::element()
                and not(local-name(following-sibling::element()[1]) eq 'section')
                (: Hvis de etterfølgende elementene er sluttanonnseringen, så trenger vi ikke FO :)
                and not(
                (count(following-sibling::element()) eq 3)
                and
                (count(following-sibling::p[@class eq 'nlb-ekstra-informasjon']) eq 2)
                )
                ">

            <!-- Ja, det trenger vi, så først bygger vi opp en overskrift basert på tidligere hovedoverskrift:
            -->
            <!--<xsl:variable name="FO" as="xs:string"
                select="concat('Fortsettelse på overskriften «', ancestor::section[1]/child::element()[matches(local-name(), '^h[1-6]$')], '»:')"/>-->
            <xsl:variable name="FO" as="xs:string">
                <xsl:choose>
                    <xsl:when test="starts-with(//meta[@name eq 'dc:language'][1]/@content, 'en')">
                        <xsl:value-of
                            select="concat('Resuming the heading ''', ancestor::section[1]/child::element()[matches(local-name(), '^h[1-6]$')], ''':')"
                        />
                    </xsl:when>
                    <xsl:when
                        test="matches(//meta[@name eq 'dc:language'][1]/@content, '^(nn-no|nn)$', 'i')">
                        <xsl:value-of
                            select="concat('Framhald av overskrifta «', ancestor::section[1]/child::element()[matches(local-name(), '^h[1-6]$')], '»:')"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of
                            select="concat('Fortsettelse på overskriften «', ancestor::section[1]/child::element()[matches(local-name(), '^h[1-6]$')], '»:')"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>


            <!-- Bestem nivået som FO skal plasseres på: -->
            <xsl:variable name="nivå" as="xs:integer" select="count(ancestor-or-self::section)"/>

            <!-- Finn fram til første etterfølgende section (er ikke sikkert at det finnes): -->
            <xsl:variable name="etterfølgende-section" as="element()?"
                select="following-sibling::section[1]"/>




            <!-- Dersom det finnes et section element blandt disse etterfølgende elementene: hent alle etterfølgende fram til dette section-elementet.
                Hvis ikke: hent alle elementene.
            -->
            <xsl:variable name="aktuelle-elementer" as="element()+">
                <xsl:choose>
                    <xsl:when test="exists($etterfølgende-section)">
                        <xsl:sequence
                            select="following-sibling::element()[. &lt;&lt; $etterfølgende-section]"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="following-sibling::element()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <!--            <xsl:message>FO: <xsl:value-of select="$FO"/></xsl:message>
            <xsl:message>elementer: <xsl:value-of select="$aktuelle-elementer/local-name()"
                /></xsl:message>-->

            <section>
                <xsl:copy-of select="@epub:type"/>
                <xsl:attribute name="id" select="concat('nlb-fo-section-', generate-id())"/>
                <xsl:element name="{concat('h',string($nivå))}">
                    <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
                    <xsl:attribute name="id" select="concat('nlb-fo-h-section-', generate-id())"/>
                    <xsl:value-of select="$FO"/>
                </xsl:element>
                <xsl:copy-of select="$aktuelle-elementer"/>
            </section>
        </xsl:if>

    </xsl:template>

    <xsl:template match="element()[local-name() ne 'section'][preceding-sibling::section]">
        <!-- Tar bort barn av section og som har en section som foranliggende søsken.
            Slike elementer ivaretas av template over    
            -->
        <!-- Med mindre det dreier seg om sluttanonseringen -->
        <xsl:if
            test="
                (local-name() eq 'hr')
                and (@class eq 'separator')
                and (every $p in following-sibling::element()
                    satisfies (local-name($p) eq 'p' and $p/@class eq 'nlb-ekstra-informasjon'))">
            <xsl:next-match/>
        </xsl:if>
        <xsl:if
            test="
                (local-name() eq 'p')
                and
                (@class eq 'nlb-ekstra-informasjon')
                and
                (local-name(preceding-sibling::element()[1]) eq 'hr')
                and
                (preceding-sibling::element()[1]/@class eq 'separator')
                and
                (every $p in following-sibling::element()
                    satisfies (local-name($p) eq 'p' and $p/@class eq 'nlb-ekstra-informasjon'))
                ">
            <xsl:next-match/>
        </xsl:if>
        <xsl:if
            test="
                (local-name() eq 'p')
                and
                (@class eq 'nlb-ekstra-informasjon')
                and
                (local-name(preceding-sibling::element()[2]) eq 'hr')
                and
                (preceding-sibling::element()[2]/@class eq 'separator')
                and
                (local-name(preceding-sibling::element()[1]) eq 'p')
                and
                (preceding-sibling::element()[1]/@class eq 'nlb-ekstra-informasjon')
                ">
            <xsl:next-match/>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
