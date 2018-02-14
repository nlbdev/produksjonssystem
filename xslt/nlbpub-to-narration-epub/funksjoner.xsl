<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        En del nyttige funksjoner
        
        Per Sennels, 14.02.2018
    -->
    
    <xsl:function name="fnk:metadata-finnes" as="xs:boolean">
        <xsl:param name="navn" as="xs:string"></xsl:param>
        <xsl:value-of select="exists($metadata[@name eq $navn])"/>
    </xsl:function>
    
    <xsl:function name="fnk:hent-metadata-fra-nlbpub" as="xs:string?">
        <xsl:param name="navn" as="xs:string"/>
        <xsl:param name="anta-én-forekomst" as="xs:boolean"/>
        <xsl:choose>
            <xsl:when test="$anta-én-forekomst">
                <xsl:value-of select="($metadata[@name eq $navn][1]/@content,concat('[MANGLER FORVENTET METADATA: ',$navn,']'))[normalize-space(.) ne ''][1]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="fnk:metadata-finnes($navn)">
                        <xsl:for-each select="$metadata[@name eq $navn]">
                            <xsl:value-of select="@content"/>
                            <xsl:choose>
                                <xsl:when test="position() eq last() -1">
                                    <xsl:choose>
                                        <xsl:when test="$SPRÅK.en">
                                            <xsl:text> and </xsl:text>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:text> og </xsl:text>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:when test="position() eq last()"></xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>, </xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat('[MANGLER FORVENTET METADATA: ',$navn,']')"/>
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
