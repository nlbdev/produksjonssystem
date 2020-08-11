<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xmlns:nlb="http://www.nlb.no/2018/xml"
    xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/" xmlns="http://www.daisy.org/z3986/2005/dtbook/"
    exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        En del nyttige funksjoner
        
        Per Sennels, 14.02.2018
    -->
    <xsl:variable name="språk-kart" as="element()"
        select="doc('language-mapping.xml')/nlb:languages"/>

    <xsl:function name="fnk:språkkode-til-tekst" as="xs:string">
        <xsl:param name="kode-som-skal-ekspanderes" as="xs:string"/>
        <xsl:param name="kode-for-returnert-tekst"/>

        <xsl:variable name="språk" as="xs:string?"
            select="$språk-kart/nlb:language[$kode-som-skal-ekspanderes = tokenize(@lang, '\s+')]/nlb:map-to[@lang eq $kode-for-returnert-tekst]"/>

        <xsl:choose>
            <xsl:when test="not($språk)">
                <xsl:value-of select="concat('[ukjent språk: ', $kode-som-skal-ekspanderes, ']')"/>
                <xsl:message>
                    <xsl:text>* Finner ikke spraak for kodene: </xsl:text>
                    <xsl:value-of select="$kode-som-skal-ekspanderes"/>
                    <xsl:text> og </xsl:text>
                    <xsl:value-of select="$kode-for-returnert-tekst"/>
                </xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$språk"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:metadata-finnes" as="xs:boolean">
        <xsl:param name="navn" as="xs:string"/>
        <xsl:value-of select="exists($metadata[@name eq $navn])"/>
    </xsl:function>

    <xsl:function name="fnk:hent-metadata-verdi" as="xs:string?">
        <xsl:param name="navn" as="xs:string"/>
        <xsl:param name="anta-én-forekomst" as="xs:boolean"/>
        <xsl:param name="normaliser-navn" as="xs:boolean"/>
        <xsl:choose>
            <xsl:when test="$anta-én-forekomst">
                <xsl:choose>
                    <xsl:when test="$normaliser-navn">
                        <xsl:value-of
                            select="(fnk:normaliser-forfatternavn($metadata[@name eq $navn][1]/@content), concat('[MANGLER FORVENTET METADATA: ', $navn, ']'))[normalize-space(.) ne ''][1]"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of
                            select="($metadata[@name eq $navn][1]/@content, concat('[MANGLER FORVENTET METADATA: ', $navn, ']'))[normalize-space(.) ne ''][1]"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="fnk:metadata-finnes($navn)">
                        <xsl:variable name="tmp" as="xs:string+">
                            <xsl:for-each select="$metadata[@name eq $navn]">
                                <xsl:choose>
                                    <xsl:when test="$normaliser-navn">
                                        <xsl:value-of
                                            select="fnk:normaliser-forfatternavn(@content)"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="@content"/>
                                    </xsl:otherwise>
                                </xsl:choose>

                                <xsl:choose>
                                    <xsl:when test="position() eq last() - 1">
                                        <xsl:choose>
                                            <xsl:when test="$SPRÅK.en">
                                                <xsl:text> and </xsl:text>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:text> og </xsl:text>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:when>
                                    <xsl:when test="position() eq last()"/>
                                    <xsl:otherwise>
                                        <xsl:text>, </xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:value-of select="string-join($tmp,'')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('[MANGLER FORVENTET METADATA: ', $navn, ']')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>


    <xsl:function name="fnk:ekstraher-isbn" as="xs:string">
        <xsl:param name="isbn" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="starts-with($isbn, 'urn:isbn:')">
                <xsl:value-of select="normalize-space(substring-after($isbn, 'urn:isbn:'))"/>
            </xsl:when>
            <xsl:when test="starts-with($isbn, 'urn:issn:')">
                <xsl:value-of select="normalize-space(substring-after($isbn, 'urn:issn:'))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space($isbn)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:normaliser-forfatternavn" as="xs:string">
        <xsl:param name="navn" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="contains($navn, ', ')">
                <xsl:value-of
                    select="normalize-space(concat(substring-after($navn, ', '), ' ', substring-before($navn, ',')))"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space($navn)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:epub-type" as="xs:boolean">
        <xsl:param name="attributtverdi" as="xs:string?"/>
        <xsl:param name="type" as="xs:string"/>

        <xsl:value-of
            select="
                some $a in tokenize(normalize-space($attributtverdi), '\s')
                    satisfies $a eq $type"
        />
    </xsl:function>

    <xsl:function name="fnk:lag-stor-førstebokstav" as="xs:string">
        <xsl:param name="tekst" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="normalize-space($tekst) eq ''">
                <xsl:value-of select="$tekst"/>
            </xsl:when>
            <xsl:when test="string-length(normalize-space($tekst)) eq 1">
                <xsl:value-of select="upper-case($tekst)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="første-bokstav" as="xs:string" select="substring($tekst, 1, 1)"/>
                <xsl:variable name="resten" as="xs:string" select="substring($tekst, 2)"/>
                <xsl:value-of select="concat(upper-case($første-bokstav), $resten)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:tall-til-tallord" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>
        <xsl:param name="intetkjønn" as="xs:boolean"/>
        <xsl:param name="hunkjønn" as="xs:boolean"/>

        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:choose>
                    <xsl:when test="$SPRÅK.en">
                        <xsl:value-of select="'one'"/>
                    </xsl:when>
                    <xsl:when test="$SPRÅK.nn">
                        <xsl:choose>
                            <xsl:when test="$intetkjønn">
                                <xsl:value-of select="'eitt'"/>
                            </xsl:when>
                            <xsl:when test="$hunkjønn">
                                <xsl:value-of select="'ei'"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="'ein'"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:choose>
                            <xsl:when test="$intetkjønn">
                                <xsl:value-of select="'ett'"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="'én'"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$tall gt 15">
                <xsl:value-of select="$tall"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="tallord" as="xs:string+">
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:sequence
                                select="
                                    ('one', 'two', 'three', 'four', 'five', 'six', 'seven',
                                    'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen')"
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
