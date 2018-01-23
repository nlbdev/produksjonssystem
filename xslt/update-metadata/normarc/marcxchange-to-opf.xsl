<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:nlb="http://metadata.nlb.no/vocabulary/#"
                xmlns:SRU="http://www.loc.gov/zing/sru/"
                xmlns:normarc="info:lc/xmlns/marcxchange-v1"
                xmlns:marcxchange="info:lc/xmlns/marcxchange-v1"
                xmlns:DIAG="http://www.loc.gov/zing/sru/diagnostics/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="nested" select="false()"/>
    
    <xsl:template match="@*|node()">
        <xsl:choose>
            <xsl:when test="self::*[@tag]">
                <xsl:message>
                    <xsl:text>Ingen regel for NORMARC-felt: </xsl:text>
                    <xsl:value-of select="@tag"/>
                    <xsl:text> (boknummer: </xsl:text>
                    <xsl:value-of select="../*[@tag='001']/text()"/>
                    <xsl:text>)</xsl:text>
                </xsl:message>
            </xsl:when>
            <xsl:when test="self::*[@code]">
                <xsl:message>
                    <xsl:text>Ingen regel for NORMARC-delfelt: </xsl:text>
                    <xsl:value-of select="parent::*/@tag"/>
                    <xsl:text> $</xsl:text>
                    <xsl:value-of select="@code"/>
                    <xsl:text> (boknummer: </xsl:text>
                    <xsl:value-of select="../../*[@tag='001']/text()"/>
                    <xsl:text>)</xsl:text>
                </xsl:message>
            </xsl:when>
            <xsl:when test="self::*">
                <!--<xsl:message
                    select="concat('marcxchange-to-opf.xsl: no match for element &quot;',concat('/',string-join((ancestor-or-self::*)/concat(name(),'[',count(preceding-sibling::*)+1,']'),'/')),'&quot; with attributes: ',string-join(for $attribute in @* return concat($attribute/name(),'=&quot;',$attribute,'&quot;'),' '))"
                />-->
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="SRU:*">
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    
    <xsl:template match="*:record[not(self::SRU:*)]">
        <xsl:variable name="metadata" as="element()">
            <metadata>
                <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                <xsl:variable name="with-duplicates" as="element()*">
                    <xsl:apply-templates select="node()"/>
                </xsl:variable>
                <xsl:variable name="without-duplicates" as="element()*">
                    <xsl:for-each select="$with-duplicates">
                        <xsl:variable name="position" select="position()"/>
                        <xsl:choose>
                            <xsl:when test="self::dc:*">
                                <xsl:if test="not($with-duplicates[position() &lt; $position and name()=current()/name() and text()=current()/text() and string(@refines)=string(current()/@refines)])">
                                    <xsl:copy>
                                        <xsl:copy-of select="$with-duplicates[self::dc:*[name()=current()/name() and text()=current()/text() and string(@refines)=string(current()/@refines)]]/@*"/>
                                        <xsl:copy-of select="node()"/>
                                    </xsl:copy>
                                </xsl:if>
                            </xsl:when>
                            <xsl:when test="self::meta">
                                <xsl:variable name="this" select="."/>
                                <xsl:if
                                    test="not($with-duplicates[position() &lt; $position and @property=current()/@property and text()=current()/text() and string(@refines)=string(current()/@refines)])">
                                    <xsl:copy>
                                        <xsl:copy-of select="$with-duplicates[self::meta[@property=current()/@property and text()=current()/text() and string(@refines)=string(current()/@refines)]]/@*"/>
                                        <xsl:copy-of select="node()"/>
                                    </xsl:copy>
                                </xsl:if>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
    
                <xsl:variable name="sorted" as="element()*">
                    <xsl:for-each select="$without-duplicates[self::dc:*[not(@refines)]]">
                        <xsl:sort
                            select="if (not(contains('dc:identifier dc:title dc:creator dc:format',name()))) then 100 else count(tokenize(substring-before('dc:identifier dc:title dc:creator dc:format',name()),' '))"/>
                        <xsl:copy-of select="."/>
                        <xsl:if test="@id">
                            <xsl:call-template name="copy-meta-refines">
                                <xsl:with-param name="meta-set" select="$with-duplicates"/>
                                <xsl:with-param name="id" select="string(@id)"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:for-each select="$without-duplicates[self::meta[starts-with(@property,'dc:') and not(@refines)]]">
                        <xsl:sort select="@property"/>
                        <xsl:copy-of select="."/>
                        <xsl:if test="@id">
                            <xsl:call-template name="copy-meta-refines">
                                <xsl:with-param name="meta-set" select="$with-duplicates"/>
                                <xsl:with-param name="id" select="string(@id)"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:for-each select="$without-duplicates[self::meta[not(starts-with(@property,'dc:')) and contains(@property,':') and not(@refines)]]">
                        <xsl:sort select="@property"/>
                        <xsl:copy-of select="."/>
                        <xsl:if test="@id">
                            <xsl:call-template name="copy-meta-refines">
                                <xsl:with-param name="meta-set" select="$with-duplicates"/>
                                <xsl:with-param name="id" select="string(@id)"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:for-each select="$without-duplicates[self::meta[not(contains(@property,':')) and not(@refines)]]">
                        <xsl:sort select="@property"/>
                        <xsl:copy-of select="."/>
                        <xsl:if test="@id">
                            <xsl:call-template name="copy-meta-refines">
                                <xsl:with-param name="meta-set" select="$with-duplicates"/>
                                <xsl:with-param name="id" select="string(@id)"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:variable>
    
                <xsl:for-each select="$sorted">
                    <!-- remove unneccessary id's on non-DC elements -->
                    <xsl:copy>
                        <xsl:copy-of select="@* except @id"/>
                        <xsl:if test="self::dc:* or @id and $sorted[@refines = concat('#',current()/@id)]">
                            <xsl:copy-of select="@id"/>
                        </xsl:if>
                        <xsl:copy-of select="node()"/>
                    </xsl:copy>
                </xsl:for-each>
            </metadata>
        </xsl:variable>
    
        <xsl:choose>
            <xsl:when test="string($nested) = 'true'">
                <xsl:for-each select="$metadata">
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:for-each select="*[not(@refines)] | comment()">
                            <xsl:choose>
                                <xsl:when test="self::comment()">
                                    <xsl:copy-of select="."/>
                                </xsl:when>
                                <xsl:when test="self::*">
                                    <xsl:apply-templates select="." mode="nesting"/>
                                </xsl:when>
                            </xsl:choose>
                        </xsl:for-each>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$metadata"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="copy-meta-refines">
        <xsl:param name="meta-set" required="yes" as="element()*"/>
        <xsl:param name="id" required="yes" as="xs:string"/>
        <xsl:variable name="idref" select="concat('#',$id)"/>
        <xsl:for-each select="$meta-set[self::meta[@refines=$idref]]">
            <xsl:sort select="@property"/>
            <xsl:copy-of select="."/>
            <xsl:if test="@id">
                <xsl:call-template name="copy-meta-refines">
                    <xsl:with-param name="meta-set" select="$meta-set"/>
                    <xsl:with-param name="id" select="string(@id)"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*" mode="nesting">
        <xsl:copy>
            <xsl:copy-of select="@* except (@property, @refines)"/>
            <xsl:if test="@property">
                <xsl:attribute name="name" select="@property"/>
            </xsl:if>
            <xsl:attribute name="content" select="text()"/>
            <xsl:if test="@id">
                <xsl:apply-templates select="../*[@refines = concat('#',current()/@id)]" mode="nesting"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <!-- 00X KONTROLLFELT -->
    
    <xsl:template match="*:leader"/>
    
    <xsl:template match="*:controlfield[@tag='001']">
        <dc:identifier id="pub-id">
            <xsl:value-of select="text()"/>
        </dc:identifier>
    </xsl:template>
    
    <xsl:template match="*:controlfield[@tag='007']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 007 FYSISK BESKRIVELSE AV DOKUMENTET'"/>-->
    </xsl:template>
    
    <xsl:template match="*:controlfield[@tag='008']">
        <xsl:variable name="POS22" select="substring(text(),23,1)"/>
        <xsl:variable name="POS33" select="substring(text(),34,1)"/>
        <xsl:variable name="POS34" select="substring(text(),35,1)"/>
        <xsl:variable name="POS35-37" select="substring(text(),36,3)"/>
    
        <xsl:choose>
            <xsl:when test="$POS22='a'">
                <meta property="audience">Adult</meta>
            </xsl:when>
            <xsl:when test="$POS22='j'">
                <meta property="audience">Juvenile</meta>
            </xsl:when>
        </xsl:choose>
    
        <xsl:choose>
            <xsl:when test="$POS33='0'">
                <meta property="dc:type.genre">Non-fiction</meta>
            </xsl:when>
            <xsl:when test="$POS33='1'">
                <meta property="dc:type.genre">Fiction</meta>
            </xsl:when>
        </xsl:choose>
    
        <xsl:choose>
            <xsl:when test="$POS34='0'">
                <meta property="dc:type.genre">Non-biography</meta>
            </xsl:when>
            <xsl:when test="$POS34='1'">
                <meta property="dc:type.genre">Biography</meta>
            </xsl:when>
            <xsl:when test="$POS34='a'">
                <meta property="dc:type.genre">Biography</meta>
                <meta property="dc:type.genre">Autobiography</meta>
            </xsl:when>
            <xsl:when test="$POS34='b'">
                <meta property="dc:type.genre">Biography</meta>
                <meta property="dc:type.genre">Individual biography</meta>
            </xsl:when>
            <xsl:when test="$POS34='c'">
                <meta property="dc:type.genre">Biography</meta>
                <meta property="dc:type.genre">Collective biography</meta>
            </xsl:when>
            <xsl:when test="$POS34='d'">
                <meta property="dc:type.genre">Biography</meta>
            </xsl:when>
        </xsl:choose>
    
        <xsl:choose>
            <xsl:when test="normalize-space($POS35-37) and normalize-space($POS35-37) != 'mul'">
                <dc:language>
                    <xsl:value-of select="$POS35-37"/>
                </dc:language>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <!-- 010 - 04X KONTROLLNUMMER OG KODER -->
    
    <xsl:template match="*:datafield[@tag='015']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 015 ANDRE BIBLIOGRAFISKE KONTROLLNUMMER'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='019']">
        <xsl:for-each select="*:subfield[@code='a']/tokenize(replace(text(),'\s',''),'[,\.\-_]')">
            <xsl:choose>
                <xsl:when test=".='a'">
                    <meta property="audience">Ages 0-5</meta>
                </xsl:when>
                <xsl:when test=".='b'">
                    <meta property="audience">Ages 6-8</meta>
                </xsl:when>
                <xsl:when test=".='bu'">
                    <meta property="audience">Ages 9-10</meta>
                </xsl:when>
                <xsl:when test=".='u'">
                    <meta property="audience">Ages 11-12</meta>
                </xsl:when>
                <xsl:when test=".='mu'">
                    <meta property="audience">Ages 13+</meta>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>
    
        <xsl:variable name="b" as="element()*">
            <xsl:for-each select="*:subfield[@code='b']/tokenize(replace(text(),'\s',''),'[,\.\-_]')">
                <xsl:choose>
                    <xsl:when test=".='a'">
                        <meta property="dc:format.other.no">Kartografisk materiale</meta>
                        <meta property="dc:format.other">Cartographic materials</meta>
                    </xsl:when>
                    <xsl:when test=".='ab'">
                        <meta property="dc:format.other.no">Kartografisk materiale</meta>
                        <meta property="dc:format.other">Cartographic materials</meta>
                        <meta property="dc:format.other.no">Atlas</meta>
                        <meta property="dc:format.other">Atlas</meta>
                    </xsl:when>
                    <xsl:when test=".='aj'">
                        <meta property="dc:format.other.no">Kartografisk materiale</meta>
                        <meta property="dc:format.other">Cartographic materials</meta>
                        <meta property="dc:format.other.no">Kart</meta>
                        <meta property="dc:format.other">Map</meta>
                    </xsl:when>
                    <xsl:when test=".='b'">
                        <meta property="dc:format.other.no">Manuskripter</meta>
                        <meta property="dc:format.other">Manuscripts</meta>
                    </xsl:when>
                    <xsl:when test=".='c'">
                        <meta property="dc:format.other.no">Musikktrykk</meta>
                        <meta property="dc:format.other">Sheet music</meta>
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                    <xsl:when test=".='d'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                    </xsl:when>
                    <xsl:when test=".='da'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Grammofonplate</meta>
                        <meta property="dc:format.other">Gramophone record</meta>
                    </xsl:when>
                    <xsl:when test=".='db'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Kassett</meta>
                        <meta property="dc:format.other">Cassette</meta>
                    </xsl:when>
                    <xsl:when test=".='dc'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">CD (kompaktplate)</meta>
                        <meta property="dc:format.other">Compact Disk</meta>
                        <dc:format>DAISY 2.02</dc:format>
                    </xsl:when>
                    <xsl:when test=".='dd'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Avspiller med lydfil</meta>
                        <meta property="dc:format.other">Player with audio file</meta>
                    </xsl:when>
                    <xsl:when test=".='de'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Digikort</meta>
                        <meta property="dc:format.other">Digikort</meta>
                    </xsl:when>
                    <xsl:when test=".='dg'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Musikk</meta>
                        <meta property="dc:format.other">Music</meta>
                    </xsl:when>
                    <xsl:when test=".='dh'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Språkkurs</meta>
                        <meta property="dc:format.other">Language course</meta>
                    </xsl:when>
                    <xsl:when test=".='di'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Lydbok</meta>
                        <meta property="dc:format.other">Audio book</meta>
                    </xsl:when>
                    <xsl:when test=".='dj'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Annen tale/annet</meta>
                        <meta property="dc:format.other">Other voice/other</meta>
                        <dc:format>DAISY 2.02</dc:format>
                    </xsl:when>
                    <xsl:when test=".='dk'">
                        <meta property="dc:format.other.no">Lydopptak</meta>
                        <meta property="dc:format.other">Audio recording</meta>
                        <meta property="dc:format.other.no">Kombidokument</meta>
                        <meta property="dc:format.other">Combined document</meta>
                    </xsl:when>
                    <xsl:when test=".='e'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                    </xsl:when>
                    <xsl:when test=".='ec'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                        <meta property="dc:format.other.no">Filmspole</meta>
                        <meta property="dc:format.other">Video tape</meta>
                    </xsl:when>
                    <xsl:when test=".='ed'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                        <meta property="dc:format.other.no">Videokassett (VHS)</meta>
                        <meta property="dc:format.other">VHS</meta>
                    </xsl:when>
                    <xsl:when test=".='ee'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                        <meta property="dc:format.other.no">Videoplate (DVD)</meta>
                        <meta property="dc:format.other">DVD</meta>
                    </xsl:when>
                    <xsl:when test=".='ef'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                        <meta property="dc:format.other.no">Blu-ray-plate</meta>
                        <meta property="dc:format.other">Blu-ray</meta>
                    </xsl:when>
                    <xsl:when test=".='eg'">
                        <meta property="dc:format.other.no">Film</meta>
                        <meta property="dc:format.other">Video</meta>
                        <meta property="dc:format.other.no">3D</meta>
                        <meta property="dc:format.other">3D</meta>
                    </xsl:when>
                    <xsl:when test=".='f'">
                        <meta property="dc:format.other.no">Grafisk materiale</meta>
                        <meta property="dc:format.other">Graphic materials</meta>
                    </xsl:when>
                    <xsl:when test=".='fd'">
                        <meta property="dc:format.other.no">Grafisk materiale</meta>
                        <meta property="dc:format.other">Graphic materials</meta>
                        <meta property="dc:format.other.no">Dias</meta>
                        <meta property="dc:format.other">Slides</meta>
                    </xsl:when>
                    <xsl:when test=".='ff'">
                        <meta property="dc:format.other.no">Grafisk materiale</meta>
                        <meta property="dc:format.other">Graphic materials</meta>
                        <meta property="dc:format.other.no">Fotografi</meta>
                        <meta property="dc:format.other">Photography</meta>
                    </xsl:when>
                    <xsl:when test=".='fi'">
                        <meta property="dc:format.other.no">Grafisk materiale</meta>
                        <meta property="dc:format.other">Graphic materials</meta>
                        <meta property="dc:format.other.no">Kunstreproduksjon</meta>
                        <meta property="dc:format.other">Art reproduction</meta>
                    </xsl:when>
                    <xsl:when test=".='g'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <dc:format>XHTML</dc:format>
                    </xsl:when>
                    <xsl:when test=".='gb'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">Diskett</meta>
                        <meta property="dc:format.other">Floppy</meta>
                    </xsl:when>
                    <xsl:when test=".='gc'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">DVD-ROM</meta>
                        <meta property="dc:format.other">DVD</meta>
                    </xsl:when>
                    <xsl:when test=".='gd'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">CD-ROM</meta>
                        <meta property="dc:format.other">CD</meta>
                    </xsl:when>
                    <xsl:when test=".='ge'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">Nettressurs</meta>
                        <meta property="dc:format.other">Web resource</meta>
                        <dc:format>XHTML</dc:format>
                    </xsl:when>
                    <xsl:when test=".='gf'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">Lagringsbrikke</meta>
                        <meta property="dc:format.other">Storage card</meta>
                    </xsl:when>
                    <xsl:when test=".='gg'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">Blu-ray ROM</meta>
                        <meta property="dc:format.other">Blu-ray</meta>
                    </xsl:when>
                    <xsl:when test=".='gh'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other">UMD</meta>
                    </xsl:when>
                    <xsl:when test=".='gi'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <meta property="dc:format.other.no">Wii-plate</meta>
                        <meta property="dc:format.other">Wii disk</meta>
                    </xsl:when>
                    <xsl:when test=".='gt'">
                        <meta property="dc:format.other.no">Elektronisk ressurs</meta>
                        <meta property="dc:format.other">Electronic resource</meta>
                        <dc:format>EPUB</dc:format>
                    </xsl:when>
                    <xsl:when test=".='h'">
                        <meta property="dc:format.other.no">Tredimensjonal gjenstand</meta>
                        <meta property="dc:format.other">Three-dimensional object</meta>
                    </xsl:when>
                    <xsl:when test=".='i'">
                        <meta property="dc:format.other.no">Mikroform</meta>
                        <meta property="dc:format.other">Microform</meta>
                    </xsl:when>
                    <xsl:when test=".='ib'">
                        <meta property="dc:format.other.no">Mikroform</meta>
                        <meta property="dc:format.other">Microform</meta>
                        <meta property="dc:format.other.no">Mikrofilmspole</meta>
                        <meta property="dc:format.other">Microfilm tape</meta>
                    </xsl:when>
                    <xsl:when test=".='ic'">
                        <meta property="dc:format.other.no">Mikroform</meta>
                        <meta property="dc:format.other">Microform</meta>
                        <meta property="dc:format.other.no">Mikrofilmkort</meta>
                        <meta property="dc:format.other">Microfilm card</meta>
                    </xsl:when>
                    <xsl:when test=".='j'">
                        <meta property="dc:format.other.no">Periodika</meta>
                        <meta property="dc:format.other">Serial</meta>
                        <meta property="periodical">true</meta>
                    </xsl:when>
                    <xsl:when test=".='jn'">
                        <meta property="dc:format.other.no">Periodika</meta>
                        <meta property="dc:format.other">Serial</meta>
                        <meta property="dc:format.other.no">Avis</meta>
                        <meta property="dc:format.other">Newspaper</meta>
                        <meta property="periodical">true</meta>
                        <meta property="newspaper">true</meta>
                    </xsl:when>
                    <xsl:when test=".='jp'">
                        <meta property="dc:format.other.no">Periodika</meta>
                        <meta property="dc:format.other">Serial</meta>
                        <meta property="dc:format.other.no">Tidsskrift</meta>
                        <meta property="dc:format.other">Magazine</meta>
                        <meta property="periodical">true</meta>
                        <meta property="magazine">true</meta>
                    </xsl:when>
                    <xsl:when test=".='k'">
                        <meta property="dc:format.other.no">Artikler</meta>
                        <meta property="dc:format.other">Article</meta>
                    </xsl:when>
                    <xsl:when test=".='l'">
                        <meta property="dc:format.other.no">Fysiske bøker</meta>
                        <meta property="dc:format.other">Physical book</meta>
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                    <xsl:when test=".='m'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                    </xsl:when>
                    <xsl:when test=".='ma'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">PC</meta>
                    </xsl:when>
                    <xsl:when test=".='mb'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Playstation 2</meta>
                    </xsl:when>
                    <xsl:when test=".='mc'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Playstation 3</meta>
                    </xsl:when>
                    <xsl:when test=".='md'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Playstation Portable</meta>
                    </xsl:when>
                    <xsl:when test=".='mi'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Xbox</meta>
                    </xsl:when>
                    <xsl:when test=".='mj'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Xbox 360</meta>
                    </xsl:when>
                    <xsl:when test=".='mn'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Nintendo DS</meta>
                    </xsl:when>
                    <xsl:when test=".='mo'">
                        <meta property="dc:format.other.no">Dataspill</meta>
                        <meta property="dc:format.other">Video game</meta>
                        <meta property="dc:format.other">Nintendo Wii</meta>
                    </xsl:when>
                    <xsl:when test=".='dl'">
                        <meta property="dc:format.other.no">SACD</meta>
                        <meta property="dc:format.other">SACD</meta>
                    </xsl:when>
                    <xsl:when test=".='dm'">
                        <meta property="dc:format.other.no">DVD-audio</meta>
                        <meta property="dc:format.other">DVD-audio</meta>
                    </xsl:when>
                    <xsl:when test=".='dn'">
                        <meta property="dc:format.other.no">Blu-Ray-audio</meta>
                        <meta property="dc:format.other">Blu-Ray-audio</meta>
                    </xsl:when>
                    <xsl:when test=".='dz'">
                        <meta property="dc:format.other.no">MP3</meta>
                        <meta property="dc:format.other">MP3</meta>
                    </xsl:when>
                    <xsl:when test=".='ea'">
                        <meta property="dc:format.other.no">E-film</meta>
                        <meta property="dc:format.other">E-film</meta>
                    </xsl:when>
                    <xsl:when test=".='ga'">
                        <meta property="dc:format.other.no">Nedlastbar fil</meta>
                        <meta property="dc:format.other">Downloadable file</meta>
                    </xsl:when>
                    <xsl:when test=".='je'">
                        <meta property="dc:format.other.no">E-tidsskrifter</meta>
                        <meta property="dc:format.other">E-periodicals</meta>
                    </xsl:when>
                    <xsl:when test=".='ka'">
                        <meta property="dc:format.other.no">E-artikler</meta>
                        <meta property="dc:format.other">E-articles</meta>
                    </xsl:when>
                    <xsl:when test=".='la'">
                        <meta property="dc:format.other.no">E-bøker</meta>
                        <meta property="dc:format.other">E-books</meta>
                    </xsl:when>
                    <xsl:when test=".='me'">
                        <meta property="dc:format.other.no">Playstation 4</meta>
                        <meta property="dc:format.other">Playstation 4</meta>
                    </xsl:when>
                    <xsl:when test=".='mk'">
                        <meta property="dc:format.other.no">Xbox One</meta>
                        <meta property="dc:format.other">Xbox One</meta>
                    </xsl:when>
                    <xsl:when test=".='mp'">
                        <meta property="dc:format.other.no">Nintendo Wii U</meta>
                        <meta property="dc:format.other">Nintendo Wii U</meta>
                    </xsl:when>
                    <xsl:when test=".='n'">
                        <meta property="dc:format.other.no">Filformater</meta>
                        <meta property="dc:format.other">File formats</meta>
                    </xsl:when>
                    <xsl:when test=".='na'">
                        <meta property="dc:format.other.no">PDF</meta>
                        <meta property="dc:format.other">PDF</meta>
                    </xsl:when>
                    <xsl:when test=".='nb'">
                        <meta property="dc:format.other.no">EPUB</meta>
                        <meta property="dc:format.other">EPUB</meta>
                    </xsl:when>
                    <xsl:when test=".='nc'">
                        <meta property="dc:format.other.no">MOBI</meta>
                        <meta property="dc:format.other">MOBI</meta>
                    </xsl:when>
                    <xsl:when test=".='nl'">
                        <meta property="dc:format.other.no">WMA (Windows Media Audio)</meta>
                        <meta property="dc:format.other">WMA (Windows Media Audio)</meta>
                    </xsl:when>
                    <xsl:when test=".='ns'">
                        <meta property="dc:format.other.no">WMV (Windows Media Video)</meta>
                        <meta property="dc:format.other">WMV (Windows Media Video)</meta>
                    </xsl:when>
                    <xsl:when test=".='o'">
                        <meta property="dc:format.other.no">Digital rettighetsadministrasjon (DRM)</meta>
                        <meta property="dc:format.other">Digital rights management (DRM)</meta>
                    </xsl:when>
                    <xsl:when test=".='te'">
                        <!-- non-standard -->
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:copy-of select="$b"/>
    
        <xsl:if test="not($b[self::dc:format])">
            <xsl:for-each select="*:subfield[@code='e']/tokenize(replace(text(),'\s',''),'[,\.\-_]')">
                <xsl:choose>
                    <xsl:when test=".='dc'">
                        <dc:format>DAISY 2.02</dc:format>
                    </xsl:when>
                    <xsl:when test=".='dj'">
                        <dc:format>DAISY 2.02</dc:format>
                    </xsl:when>
                    <xsl:when test=".='te'">
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                    <xsl:when test=".='c'">
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                    <xsl:when test=".='l'">
                        <dc:format>Braille</dc:format>
                        <meta property="dc:format.no">Punktskrift</meta>
                    </xsl:when>
                    <xsl:when test=".='gt'">
                        <dc:format>EPUB</dc:format>
                    </xsl:when>
                    <xsl:when test=".='ge'">
                        <dc:format>XHTML</dc:format>
                    </xsl:when>
                    <xsl:when test=".='g'">
                        <dc:format>XHTML</dc:format>
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>
        </xsl:if>
    
        <xsl:for-each select="*:subfield[@code='d']/(for $i in (1 to string-length(text())) return substring(text(),$i,1))">
            <xsl:choose>
                <xsl:when test=".='N'">
                    <meta property="dc:type.genre">Biography</meta>
                    <meta property="dc:type.genre">short story</meta>
                </xsl:when>
                <xsl:when test=".='B'">
                    <meta property="dc:type.genre">Biography</meta>
                    <meta property="dc:type.genre">short story</meta>
                </xsl:when>
                <xsl:when test=".='D'">
                    <meta property="dc:type.genre">poem</meta>
                </xsl:when>
                <xsl:when test=".='R'">
                    <meta property="dc:type.genre">poem</meta>
                </xsl:when>
                <xsl:when test=".='S'">
                    <meta property="dc:type.genre">play</meta>
                </xsl:when>
                <xsl:when test=".='T'">
                    <meta property="dc:type.genre">cartoon</meta>
                </xsl:when>
                <xsl:when test=".='A'">
                    <meta property="dc:type.genre">anthology</meta>
                </xsl:when>
                <xsl:when test=".='L'">
                    <meta property="dc:type.genre">textbook</meta>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='020']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="isbn">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='022']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="issn">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='041']">
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:variable name="text" select="text()"/>
            <xsl:for-each select="(1 to xs:integer(floor(string-length($text) div 3)))">
                <dc:language>
                    <xsl:value-of select="substring($text,1+(.-1)*3,3)"/>
                </dc:language>
            </xsl:for-each>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='h']">
            <xsl:variable name="text" select="text()"/>
            <xsl:for-each select="(1 to xs:integer(floor(string-length($text) div 3)))">
                <meta property="dc:language.original{if (position() lt last()) then '.intermediary' else ''}">
                    <xsl:value-of select="substring($text,1+(.-1)*3,3)"/>
                </meta>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 050 - 099 KLASSIFIKASJONSKODER -->
    
    <xsl:template match="*:datafield[@tag='082']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:subject.dewey">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="dc:subject.dewey">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[matches(@tag,'09\d')]">
        <!--<xsl:message select="'NORMARC-felt ignorert: 09X LOKALT FELT'"/>-->
    </xsl:template>
    
    <!-- 1XX HOVEDORDNINGSORD -->
    
    <xsl:template match="*:datafield[@tag='100']">
        <xsl:variable name="creator-id" select="concat('creator-',1+count(preceding-sibling::*:datafield[@tag='100' or @tag='110']))"/>
        <xsl:variable name="name" select="(*:subfield[@code='q'], *:subfield[@code='a'], *:subfield[@code='w'])[normalize-space(.)][1]/text()"/>
        
        <dc:creator id="{$creator-id}">
            <xsl:value-of select="if (contains($name,',')) then concat(normalize-space(substring-after($name,',')),' ',normalize-space(substring-before($name,','))) else $name"/>
        </dc:creator>
        
        <xsl:if test="contains($name,',')">
            <meta property="file-as" refines="#{$creator-id}">
                <xsl:value-of select="$name"/>
            </meta>
        </xsl:if>
    
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="honorificSuffix" refines="#{$creator-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='c']">
            <xsl:choose>
                <xsl:when test="matches(text(), $PSEUDONYM)">
                    <xsl:variable name="pseudonym" select="replace(text(), $PSEUDONYM_REPLACE, '$1')"/>
                    <meta property="pseudonym" refines="#{$creator-id}">
                        <xsl:value-of select="$pseudonym"/>
                    </meta>
                </xsl:when>
                <xsl:otherwise>
                    <meta property="honorificPrefix" refines="#{$creator-id}">
                        <xsl:value-of select="text()"/>
                    </meta>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='d']">
            <xsl:variable name="birthDeath" select="tokenize(nlb:parseBirthDeath(text()), ',')"/>
            <xsl:if test="$birthDeath[1]">
                <meta property="birthDate" refines="#{$creator-id}">
                    <xsl:value-of select="$birthDeath[1]"/>
                </meta>
            </xsl:if>
            <xsl:if test="$birthDeath[2]">
                <meta property="deathDate" refines="#{$creator-id}">
                    <xsl:value-of select="$birthDeath[2]"/>
                </meta>
            </xsl:if>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='j']/tokenize(replace(text(),'[\.,? ]',''), '-')">
            <xsl:variable name="nationality" select="nlb:parseNationality(.)"/>
            <meta property="nationality" refines="#{$creator-id}">
                <xsl:value-of select="$nationality"/>
            </meta>
        </xsl:for-each>
        
        <xsl:for-each select="*:subfield[@code='3']">
            <meta property="bibliofil-id" refines="#{$creator-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='110']">
        <xsl:variable name="creator-id" select="concat('creator-',1+count(preceding-sibling::*:datafield[@tag='100' or @tag='110']))"/>
        <xsl:choose>
            <xsl:when test="*:subfield[@code='a']">
                <dc:creator id="{$creator-id}">
                    <xsl:value-of select="*:subfield[@code='a']/text()"/>
                </dc:creator>
                <xsl:if test="*:subfield[@code='b']">
                    <meta property="department" refines="#{$creator-id}">
                        <xsl:value-of select="*:subfield[@code='b']/text()"/>
                    </meta>
                </xsl:if>
            </xsl:when>
            <xsl:when test="*:subfield[@code='b']">
                <dc:creator id="{$creator-id}">
                    <xsl:value-of select="*:subfield[@code='b']/text()"/>
                </dc:creator>
            </xsl:when>
        </xsl:choose>
        
        <xsl:for-each select="*:subfield[@code='3']">
            <meta property="bibliofil-id" refines="#{$creator-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 2XX TITTEL-, ANSVARS- OG UTGIVELSESOPPLYSNINGER -->
    
    <xsl:template match="*:datafield[@tag='240']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.alternative">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='245']">
        <xsl:for-each select="*:subfield[@code='a']">
            <dc:title>
                <xsl:value-of select="text()"/>
            </dc:title>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="dc:title.subTitle.other">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='h']">
            <xsl:choose>
                <xsl:when test="matches(text(),'.*da[i\\ss][si]y[\\.\\s]*.*','i') or matches(text(),'.*2[.\\s]*0?2.*','i')">
                    <dc:format>DAISY 2.02</dc:format>
                </xsl:when>
                <xsl:when test="matches(text(),'.*dtbook.*','i')">
                    <dc:type>Full Text</dc:type>
                    <dc:format>EPUB</dc:format>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='n']">
            <meta property="position">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='p']">
            <meta property="dc:title.subTitle">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='w']">
            <meta property="dc:title.part.sortingKey">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='246']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.alternative">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="dc:title.subTitle.alternative.other">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        
        <xsl:for-each select="*:subfield[@code='n']">
            <meta property="position">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        
        <xsl:for-each select="*:subfield[@code='p']">
            <meta property="dc:title.subTitle.alternative">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='250']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="bookEdition">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='260']">
        <xsl:if test="*:subfield[@code='b']">
            <xsl:variable name="publisher-id" select="concat('publisher-260-',1+count(preceding-sibling::*:datafield[@tag='260']))"/>
            
            <dc:publisher id="{$publisher-id}">
                <xsl:value-of select="(*:subfield[@code='b'])[1]/text()"/>
            </dc:publisher>
            
            <xsl:for-each select="*:subfield[@code='a']">
                <meta property="dc:publisher.location" refines="#{$publisher-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$publisher-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
        
        <xsl:for-each select="*:subfield[@code='c']">
            <meta property="dc:date.issued">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='9' and text()='n']">
            <meta property="watermark">none</meta>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 3XX FYSISK BESKRIVELSE -->
    
    <xsl:template match="*:datafield[@tag='300']">
        <xsl:variable name="fields" as="element()*">
            <xsl:apply-templates select="../*:datafield[@tag='245']"/>
        </xsl:variable>
        <xsl:variable name="fields" as="element()*">
            <xsl:choose>
                <xsl:when test="$fields[self::dc:format]">
                    <xsl:copy-of select="$fields"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="../*:datafield[@tag='019']"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:choose>
                <xsl:when test="$fields[self::dc:format]='DAISY 2.02'">
                    <xsl:choose>
                        <xsl:when test="matches(text(),'^.*?\d+ *t+\.? *\d+ *min\.?.*?$')">
                            <meta property="dc:format.extent.duration">
                                <xsl:value-of select="replace(text(),'^.*?(\d+) *t+\.? *(\d+) *min\.?.*?$','$1 t. $2 min.')"/>
                            </meta>
                        </xsl:when>
                        <xsl:when test="matches(text(),'^.*?\d+ *min\.?.*?$')">
                            <meta property="dc:format.extent.duration">
                                <xsl:value-of select="replace(text(),'^.*?(\d+) *min\.?.*?$','0 t. $1 min.')"/>
                            </meta>
                        </xsl:when>
                        <xsl:when test="matches(text(),'^.*?\d+ *t\.?.*?$')">
                            <meta property="dc:format.extent.duration">
                                <xsl:value-of select="replace(text(),'^.*?(\d+) *t\.?.*?$','$1 t. 0 min.')"/>
                            </meta>
                        </xsl:when>
                        <xsl:otherwise>
                            <meta property="dc:format.extent">
                                <xsl:value-of select="text()"/>
                            </meta>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <meta property="dc:format.extent">
                        <xsl:value-of select="text()"/>
                    </meta>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='310']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="periodicity">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 4XX SERIEANGIVELSER -->
    
    <xsl:template match="*:datafield[@tag='440']">
        <xsl:variable name="title-id" select="concat('series-title-',1+count(preceding-sibling::*:datafield[@tag='440' or @tag='490']))"/>
    
        <xsl:variable name="series-title" as="element()?">
            <xsl:if test="*:subfield[@code='a']">
                <meta property="dc:title.series" id="{$title-id}">
                    <xsl:value-of select="*:subfield[@code='a'][1]/text()"/>
                </meta>
            </xsl:if>
        </xsl:variable>
        <xsl:copy-of select="$series-title"/>
        <xsl:for-each select="*:subfield[@code='p']">
            <meta property="dc:title.subSeries">
                <xsl:if test="$series-title">
                    <xsl:attribute name="refines" select="concat('#',$title-id)"/>
                </xsl:if>
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='x']">
            <meta property="series.issn">
                <xsl:if test="$series-title">
                    <xsl:attribute name="refines" select="concat('#',$title-id)"/>
                </xsl:if>
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='v']">
            <meta property="series.position">
                <xsl:if test="$series-title">
                    <xsl:attribute name="refines" select="concat('#',$title-id)"/>
                </xsl:if>
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='449']">
        <xsl:for-each select="*:subfield[@code='n']">
            <meta property="dc:format.extent.cd">
                <xsl:value-of select="concat(text(),' CDs')"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='490']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 490 SERIEANGIVELSE UTEN BIINNFØRSEL'"/>-->
    </xsl:template>
    
    <!-- 5XX NOTER -->
    
    <xsl:template match="*:datafield[@tag='500']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 500 GENERELL NOTE'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='501']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 490 &quot;SAMMEN MED&quot;-NOTE'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='503']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="bookEdition.history">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='505']">
        <!-- what's 505$a? prodnote? -->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='511']">
        <xsl:variable name="contributor-id" select="concat('contributor-511-',1+count(preceding-sibling::*:datafield[@tag='511']))"/>
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:variable name="contributor-name" select="text()"/>
            <meta property="dc:contributor.narrator">
                <xsl:if test="position() = 1">
                    <xsl:attribute name="id" select="$contributor-id"/>
                    <xsl:value-of select="if (contains($contributor-name,',')) then concat(normalize-space(substring-after($contributor-name,',')),' ',normalize-space(substring-before($contributor-name,','))) else $contributor-name"/>
                </xsl:if>
            </meta>
            
            <xsl:if test="contains($contributor-name,',')">
                <meta property="file-as" refines="#{$contributor-id}">
                    <xsl:value-of select="$contributor-name"/>
                </meta>
            </xsl:if>
    
            <xsl:variable name="pos" select="position()"/>
            <xsl:for-each select="../*:subfield[@code='3'][position() = $pos]">
                <meta property="bibliofil-id" refines="#{$contributor-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='520']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:description.abstract">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='533']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 533 FYSISK BESKRIVELSE'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='539']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 539 SERIER'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='574']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.original">
                <xsl:value-of select="replace(text(),'^\s*Ori?ginaltit\w*\s*:?\s*','')"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='590']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 590 LOKALE NOTER'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='592']">
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:variable name="available" select="nlb:parseDate(text())"/>
            <xsl:if test="$available">
                <meta property="dc:date.available">
                    <xsl:value-of select="$available"/>
                </meta>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='593']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 593 LOKALE NOTER'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='594']">
        <!-- Karakteristikk (fulltekst/lettlest/musikk/...) - se emneordprosjektet -->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='596']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:publisher.original.location">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="dc:publisher.original">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='c']">
            <meta property="dc:date.issued.original">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='d']">
            <meta property="bookEdition.original">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='e']">
            <xsl:choose>
                <xsl:when test="matches(text(),'^\s*\d+\s*s?[\.\s]*$')">
                    <meta property="dc:format.extent.pages.original">
                        <xsl:value-of select="replace(text(),'[^\d]','')"/>
                    </meta>
                </xsl:when>
                <xsl:otherwise>
                    <meta property="dc:format.extent.original">
                        <xsl:value-of select="text()"/>
                    </meta>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='f']">
            <meta property="isbn.original">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='597']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 597 LOKALE NOTER'"/>-->
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='598']">
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:choose>
                <xsl:when test="contains(text(),'RNIB')">
                    <meta property="external-production">RNIB</meta>
                </xsl:when>
                <xsl:when test="contains(text(),'TIGAR')">
                    <meta property="external-production">TIGAR</meta>
                </xsl:when>
                <xsl:when test="contains(text(),'INNKJØPT')">
                    <meta property="external-production">WIPS</meta>
                </xsl:when>
            </xsl:choose>
            <xsl:variable name="tag592">
                <xsl:apply-templates select="../../*:datafield[@tag='592']"/>
            </xsl:variable>
            <xsl:if test="not($tag592/meta[@property='dc:date.available'])">
                <xsl:variable name="available" select="nlb:parseDate(text())"/>
                <xsl:if test="$available">
                    <meta property="dc:date.available">
                        <xsl:value-of select="$available"/>
                    </meta>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 6XX EMNEINNFØRSLER -->
    
    <xsl:template match="*:datafield[@tag='600']">
        <xsl:for-each select="*:subfield[@code='0']">
            <meta property="dc:subject.keyword">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='x']">
            <meta property="dc:subject.keyword">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='1']">
            <meta property="dc:subject.dewey">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:variable name="subject-id" select="concat('subject-600-',1+count(preceding-sibling::*:datafield[@tag='600']))"/>
        <xsl:variable name="name" select="(*:subfield[@code='q'], *:subfield[@code='a'], *:subfield[@code='w'])[normalize-space(.)][1]/text()"/>
        
        <xsl:if test="not($name='')">
    
            <dc:subject id="{$subject-id}">
                <xsl:value-of select="if (contains($name,',')) then concat(normalize-space(substring-after($name,',')),' ',normalize-space(substring-before($name,','))) else $name"/>
            </dc:subject>
            
            <xsl:if test="contains($name,',')">
                <meta property="file-as" refines="#{$subject-id}">
                    <xsl:value-of select="$name"/>
                </meta>
            </xsl:if>
    
            <xsl:for-each select="*:subfield[@code='b']">
                <meta property="honorificSuffix" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='c']">
                <xsl:choose>
                    <xsl:when test="matches(text(), $PSEUDONYM)">
                        <xsl:variable name="pseudonym" select="replace(text(), $PSEUDONYM_REPLACE, '$1')"/>
                        <meta property="pseudonym" refines="#{$subject-id}">
                            <xsl:value-of select="$pseudonym"/>
                        </meta>
                    </xsl:when>
                    <xsl:otherwise>
                        <meta property="honorificPrefix" refines="#{$subject-id}">
                            <xsl:value-of select="text()"/>
                        </meta>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='d']">
                <xsl:variable name="birthDeath" select="tokenize(nlb:parseBirthDeath(text()), ',')"/>
                <xsl:if test="$birthDeath[1]">
                    <meta property="birthDate" refines="#{$subject-id}">
                        <xsl:value-of select="$birthDeath[1]"/>
                    </meta>
                </xsl:if>
                <xsl:if test="$birthDeath[2]">
                    <meta property="deathDate" refines="#{$subject-id}">
                        <xsl:value-of select="$birthDeath[2]"/>
                    </meta>
                </xsl:if>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='j']/tokenize(replace(text(),'[\.,? ]',''), '-')">
                <xsl:variable name="nationality" select="nlb:parseNationality(.)"/>
                <meta property="nationality" refines="#{$subject-id}">
                    <xsl:value-of select="$nationality"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='610']">
        <xsl:variable name="subject-id" select="concat('subject-610-',1+count(preceding-sibling::*:datafield[@tag='610']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='b']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='q']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='611']">
        <xsl:variable name="subject-id" select="concat('subject-611-',1+count(preceding-sibling::*:datafield[@tag='611']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='650']">
        <xsl:variable name="subject-id" select="concat('subject-650-',1+count(preceding-sibling::*:datafield[@tag='650']))"/>
    
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
            
            <xsl:if test="*:subfield[@code='a']/text()=('Tidsskrifter','Avis')">
                <meta property="periodical">true</meta>
            </xsl:if>
            <xsl:if test="*:subfield[@code='a']/text()='Tidsskrifter'">
                <meta property="magazine">true</meta>
            </xsl:if>
            <xsl:if test="*:subfield[@code='a']/text()='Avis'">
                <meta property="newspaper">true</meta>
            </xsl:if>
    
            <xsl:for-each select="*:subfield[@code='0']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='c']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='d']">
                <meta property="dc:subject.time" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='q']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='w']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='x']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='z']">
                <meta property="dc:subject.location" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='651']">
        <xsl:variable name="subject-id" select="concat('subject-651-',1+count(preceding-sibling::*:datafield[@tag='651']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.location" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='q']">
                <meta property="dc:subject.location" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='x']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='z']">
                <meta property="dc:subject.location" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='653']">
        <xsl:variable name="subject-id" select="concat('subject-653-',1+count(preceding-sibling::*:datafield[@tag='653']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
            
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='c']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='q']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='x']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='655']">
        <xsl:variable name="subject-id" select="concat('subject-655-',1+count(preceding-sibling::*:datafield[@tag='655']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <xsl:variable name="mainGenre" select="*:subfield[@code='a']/text()"/>
            <xsl:variable name="subGenre" as="xs:string*">
                <xsl:for-each select="*:subfield[@code='x']">
                    <xsl:sort/>
                    <xsl:sequence select="text()"/>
                </xsl:for-each>
                <xsl:for-each select="*:subfield[@code='9']">
                    <xsl:choose>
                        <xsl:when test="normalize-space(.) = ('nno','nob','non','nor','n')">
                            <xsl:sequence select="'Norsk'"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="."/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="genre" select="if (count($subGenre)) then concat($mainGenre, ' (', string-join($subGenre,'/'), ')') else $mainGenre"/>
            
            <meta property="dc:type.genre" id="{$subject-id}">
                <xsl:value-of select="$genre"/>
            </meta>
            <meta property="dc:type.genre.no" refines="#{$subject-id}">
                <xsl:value-of select="$genre"/>
            </meta>
            <meta property="dc:type.mainGenre" refines="#{$subject-id}">
                <xsl:value-of select="$mainGenre"/>
            </meta>
            <xsl:for-each select="$subGenre">
                <meta property="dc:type.subGenre" refines="#{$subject-id}">
                    <xsl:value-of select="."/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='691']">
        <xsl:variable name="subject-id" select="concat('subject-691-',1+count(preceding-sibling::*:datafield[@tag='691']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='x']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='692']">
        <xsl:variable name="subject-id" select="concat('subject-692-',1+count(preceding-sibling::*:datafield[@tag='692']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='693']">
        <xsl:variable name="subject-id" select="concat('subject-693-',1+count(preceding-sibling::*:datafield[@tag='693']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='699']">
        <xsl:variable name="subject-id" select="concat('subject-699-',1+count(preceding-sibling::*:datafield[@tag='699']))"/>
        
        <xsl:if test="*:subfield[@code='a']">
            <meta property="dc:subject.keyword" id="{$subject-id}">
                <xsl:value-of select="*:subfield[@code='a']/text()"/>
            </meta>
            
            <xsl:for-each select="*:subfield[@code='1']">
                <meta property="dc:subject.dewey" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='c']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='d']">
                <meta property="dc:subject.time" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='q']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='x']">
                <meta property="dc:subject.keyword" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='z']">
                <meta property="location" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
    
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$subject-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <!-- 700 - 75X BIINNFØRSLER -->
    
    <xsl:template match="*:datafield[@tag='700']">
        <xsl:variable name="contributor-id" select="concat('contributor-700-',1+count(preceding-sibling::*:datafield[@tag='700']))"/>
        <xsl:variable name="name" select="(*:subfield[@code='q'], *:subfield[@code='a'], *:subfield[@code='w'])[normalize-space(.)][1]/text()"/>
        
        <xsl:variable name="role" select="nlb:parseRole(concat('',(*:subfield[@code='e'], *:subfield[@code='r'], *:subfield[@code='x'])[1]/text()))"/>
        <xsl:variable name="role" select="if ($role='dc:creator') then 'dc:contributor.other' else $role">
            <!-- because 700 never is the main author -->
        </xsl:variable>
    
        <xsl:choose>
            <xsl:when test="matches($role,'^dc:\w+$')">
                <xsl:element name="{$role}">
                    <xsl:attribute name="id" select="$contributor-id"/>
                    <xsl:value-of select="if (contains($name,',')) then concat(normalize-space(substring-after($name,',')),' ',normalize-space(substring-before($name,','))) else $name"/>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <meta property="{$role}" id="{$contributor-id}">
                    <xsl:value-of select="if (contains($name,',')) then concat(normalize-space(substring-after($name,',')),' ',normalize-space(substring-before($name,','))) else $name"/>
                </meta>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:if test="contains($name,',')">
            <meta property="file-as" refines="#{$contributor-id}">
                <xsl:value-of select="$name"/>
            </meta>
        </xsl:if>
        
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="honorificSuffix" refines="#{$contributor-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='c']">
            <xsl:choose>
                <xsl:when test="matches(text(), $PSEUDONYM)">
                    <xsl:variable name="pseudonym" select="replace(text(), $PSEUDONYM_REPLACE, '$1')"/>
                    <meta property="pseudonym" refines="#{$contributor-id}">
                        <xsl:value-of select="$pseudonym"/>
                    </meta>
                </xsl:when>
                <xsl:otherwise>
                    <meta property="honorificPrefix" refines="#{$contributor-id}">
                        <xsl:value-of select="text()"/>
                    </meta>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='d']">
            <xsl:variable name="birthDeath" select="tokenize(nlb:parseBirthDeath(text()), ',')"/>
            <xsl:if test="$birthDeath[1]">
                <meta property="birthDate" refines="#{$contributor-id}">
                    <xsl:value-of select="$birthDeath[1]"/>
                </meta>
            </xsl:if>
            <xsl:if test="$birthDeath[2]">
                <meta property="deathDate" refines="#{$contributor-id}">
                    <xsl:value-of select="$birthDeath[2]"/>
                </meta>
            </xsl:if>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='j']/tokenize(replace(text(),'[\.,? ]',''), '-')">
            <xsl:variable name="nationality" select="nlb:parseNationality(.)"/>
            <meta property="nationality" refines="#{$contributor-id}">
                <xsl:value-of select="$nationality"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='3']">
            <meta property="bibliofil-id" refines="#{$contributor-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='710']">
        <xsl:for-each select="*:subfield[@code='1']">
            <meta property="dc:subject.dewey">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        
        <xsl:if test="*:subfield[@code='a']">
            <xsl:variable name="contributor-id" select="concat('contributor-700-',1+count(preceding-sibling::*:datafield[@tag='700']))"/>
            
            <dc:contributor id="{$contributor-id}">
                <xsl:value-of select="*:subfield[@code='a'][1]/text()"/>
            </dc:contributor>
            
            <xsl:for-each select="*:subfield[@code='3']">
                <meta property="bibliofil-id" refines="#{$contributor-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='730']">
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.alternative">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='740']">
        <xsl:if test="*:subfield[@code='a']">
            <xsl:variable name="title-id" select="concat('title-740-',1+count(preceding-sibling::*:datafield[@tag='740']))"/>
            <xsl:for-each select="*:subfield[@code='a']">
                <meta property="dc:title.part" id="{$title-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='b']">
                <meta property="dc:title.part.subTitle.other" refines="#{$title-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='n']">
                <meta property="position" refines="#{$title-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='p']">
                <meta property="dc:title.part.subTitle" refines="#{$title-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
            <xsl:for-each select="*:subfield[@code='w']">
                <meta property="dc:title.part.sortingKey" refines="#{$title-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <!-- 760 - 79X LENKER / RELASJONER -->
    
    <xsl:template match="*:datafield[@tag='780']">
        <xsl:variable name="series-preceding-id" select="concat('series-preceding-',1+count(preceding-sibling::*:datafield[@tag='780']))"/>
    
        <xsl:if test="*:subfield[@code='t']">
            <meta property="dc:title.series.preceding" id="{$series-preceding-id}">
                <xsl:value-of select="*:subfield[@code='t']/text()"/>
            </meta>
        </xsl:if>
        <xsl:for-each select="*:subfield[@code='w']">
            <meta property="dc:identifier.series.preceding.uri" refines="#{$series-preceding-id}">
                <xsl:value-of select="concat('urn:NBN:no-nb_nlb_',text())"/>
            </meta>
            <meta property="dc:identifier.series.preceding">
                <xsl:choose>
                    <xsl:when test="parent::*/*:subfield[@code='t']">
                        <xsl:attribute name="refines" select="concat('#',$series-preceding-id)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="id" select="$series-preceding-id"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.series.preceding.alternative" refines="#{$series-preceding-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='785']">
        <xsl:variable name="series-sequel-id" select="concat('series-sequel-',1+count(preceding-sibling::*:datafield[@tag='785']))"/>
    
        <xsl:for-each select="*:subfield[@code='t']">
            <meta property="dc:title.series.sequel" id="{$series-sequel-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='w']">
            <meta property="dc:identifier.series.sequel.uri" refines="#{$series-sequel-id}">
                <xsl:value-of select="concat('urn:NBN:no-nb_nlb_',text())"/>
            </meta>
            <meta property="dc:identifier.series.sequel">
                <xsl:choose>
                    <xsl:when test="parent::*/*:subfield[@code='t']">
                        <xsl:attribute name="refines" select="concat('#',$series-sequel-id)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="id" select="$series-sequel-id"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
        <xsl:for-each select="*:subfield[@code='a']">
            <meta property="dc:title.series.sequel.alternative" refines="#{$series-sequel-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 800 - 830 SERIEINNFØRSLER - ANNEN FORM ENN SERIEFELTET -->
    
    <xsl:template match="*:datafield[@tag='800']">
        <xsl:variable name="creator-id" select="concat('series-creator-',1+count(preceding-sibling::*:datafield[@tag='800']))"/>
        <xsl:variable name="name" select="(*:subfield[@code='q'], *:subfield[@code='a'], *:subfield[@code='w'])[normalize-space(.)][1]/text()"/>
        
        <dc:creator.series id="{$creator-id}">
            <xsl:value-of select="if (contains($name,',')) then concat(normalize-space(substring-after($name,',')),' ',normalize-space(substring-before($name,','))) else $name"/>
        </dc:creator.series>
        
        <xsl:if test="contains($name,',')">
            <meta property="file-as" refines="#{$creator-id}">
                <xsl:value-of select="$name"/>
            </meta>
        </xsl:if>
        
        <xsl:for-each select="*:subfield[@code='t']">
            <xsl:variable name="alternate-title" select="string((../../*:datafield[@tag='440']/*:subfield[@code='a'])[1]/text()) != (text(),'')"/>
            <meta property="dc:title.series{if ($alternate-title or preceding-sibling::*[@code='t']) then '.alternate' else ''}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='b']">
            <meta property="honorificSuffix" refines="#{$creator-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='c']">
            <xsl:choose>
                <xsl:when test="matches(text(), $PSEUDONYM)">
                    <xsl:variable name="pseudonym" select="replace(text(), $PSEUDONYM_REPLACE, '$1')"/>
                    <meta property="pseudonym" refines="#{$creator-id}">
                        <xsl:value-of select="$pseudonym"/>
                    </meta>
                </xsl:when>
                <xsl:otherwise>
                    <meta property="honorificPrefix" refines="#{$creator-id}">
                        <xsl:value-of select="text()"/>
                    </meta>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='d']">
            <xsl:variable name="birthDeath" select="tokenize(nlb:parseBirthDeath(text()), ',')"/>
            <xsl:if test="$birthDeath[1]">
                <meta property="birthDate" refines="#{$creator-id}">
                    <xsl:value-of select="$birthDeath[1]"/>
                </meta>
            </xsl:if>
            <xsl:if test="$birthDeath[2]">
                <meta property="deathDate" refines="#{$creator-id}">
                    <xsl:value-of select="$birthDeath[2]"/>
                </meta>
            </xsl:if>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='j']/tokenize(replace(text(),'[\.,? ]',''), '-')">
            <xsl:variable name="nationality" select="nlb:parseNationality(.)"/>
            <meta property="nationality" refines="#{$creator-id}">
                <xsl:value-of select="$nationality"/>
            </meta>
        </xsl:for-each>
    
        <xsl:for-each select="*:subfield[@code='3']">
            <meta property="bibliofil-id" refines="#{$creator-id}">
                <xsl:value-of select="text()"/>
            </meta>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 85X LOKALISERINGSDATA -->
    
    <xsl:template match="*:datafield[@tag='850']">
        <xsl:for-each select="*:subfield[@code='a']">
            <xsl:if test="text()=('NLB/S')">
                <meta property="audience">Student</meta>
                <meta property="dc:type.genre">textbook</meta>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*:datafield[@tag='856']">
        <!--<xsl:message select="'NORMARC-felt ignorert: 856 ELEKTRONISK LOKALISERING OG TILGANG'"/>-->
    </xsl:template>
    
    <!-- 9XX HENVISNINGER -->
    
    <!-- TODO: 911c and 911d (TIGAR project) -->
    
    <xsl:template match="*:datafield[@tag='996']">
        <xsl:variable name="websok-id" select="concat('websok-',1+count(preceding-sibling::*:datafield[@tag='996']))"/>
    
        <xsl:if test="*:subfield[@code='u']">
            <meta property="websok.url" id="{$websok-id}">
                <xsl:value-of select="*:subfield[@code='u']/text()"/>
            </meta>
    
            <xsl:for-each select="*:subfield[@code='t']">
                <meta property="websok.type" refines="#{$websok-id}">
                    <xsl:value-of select="text()"/>
                </meta>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xsl:variable name="DAY_MONTH_YEAR" select="'\d+-\d+-\d+'"/>
    <xsl:variable name="FORMAT_245H_DAISY2_1" select="'(?i).*da[i\ss][si]y[\.\s]*.*'"/>
    <xsl:variable name="FORMAT_245H_DAISY2_2" select="'.*2[.\s]*0?2.*'"/>
    <xsl:variable name="FORMAT_245H_DTBOOK" select="'(?i).*dtbook.*'"/>
    <xsl:variable name="PSEUDONYM" select="'pse[uv]d.*'"/>
    <xsl:variable name="PSEUDONYM_REPLACE" select="'pse[uv]d.*?f.*?\s+(.*)$'"/>
    <xsl:variable name="FIRST_LAST_NAME" select="'^(.*\S.*)\s+(\S+)\s*$'"/>
    <xsl:variable name="YEAR" select="'.*[^\d-].*'"/>
    <xsl:variable name="YEAR_NEGATIVE" select="'.*f.*(Kr.*)?'"/>
    <xsl:variable name="YEAR_VALUE" select="'[^\d]'"/>
    <xsl:variable name="AVAILABLE" select="'^.*?(\d+)[\./]+(\d+)[\./]+(\d+).*?$'"/>
    <xsl:variable name="DEWEY" select="'^.*?(\d+\.?\d*).*?$'"/>
    
    <xsl:function name="nlb:parseNationality">
        <xsl:param name="nationality"/>
        <xsl:choose>
            <xsl:when test="$nationality='somal'">
                <xsl:sequence select="'so'"/>
            </xsl:when>
            <xsl:when test="$nationality='ned'">
                <xsl:sequence select="'nl'"/>
            </xsl:when>
            <xsl:when test="$nationality='am'">
                <xsl:sequence select="'us'"/>
            </xsl:when>
            <xsl:when test="$nationality='liban'">
                <xsl:sequence select="'lb'"/>
            </xsl:when>
            <xsl:when test="$nationality='skzimb'">
                <xsl:sequence select="'sw'"/>
            </xsl:when>
            <xsl:when test="$nationality='pal'">
                <xsl:sequence select="'ps'"/>
            </xsl:when>
            <xsl:when test="$nationality='kongol'">
                <xsl:sequence select="'cd'"/>
            </xsl:when>
            <xsl:when test="$nationality='som'">
                <xsl:sequence select="'so'"/>
            </xsl:when>
            <xsl:when test="$nationality='n'">
                <xsl:sequence select="'no'"/>
            </xsl:when>
            <xsl:when test="$nationality='bulg'">
                <xsl:sequence select="'bg'"/>
            </xsl:when>
            <xsl:when test="$nationality='kan'">
                <xsl:sequence select="'ca'"/>
            </xsl:when>
            <xsl:when test="$nationality='eng'">
                <xsl:sequence select="'gb'"/>
            </xsl:when>
            <xsl:when test="$nationality='ind'">
                <xsl:sequence select="'in'"/>
            </xsl:when>
            <xsl:when test="$nationality='sv'">
                <xsl:sequence select="'se'"/>
            </xsl:when>
            <xsl:when test="$nationality='newzeal'">
                <xsl:sequence select="'nz'"/>
            </xsl:when>
            <xsl:when test="$nationality='pol'">
                <xsl:sequence select="'pl'"/>
            </xsl:when>
            <xsl:when test="$nationality='gr'">
                <xsl:sequence select="'gr'"/>
            </xsl:when>
            <xsl:when test="$nationality='fr'">
                <xsl:sequence select="'fr'"/>
            </xsl:when>
            <xsl:when test="$nationality='belg'">
                <xsl:sequence select="'be'"/>
            </xsl:when>
            <xsl:when test="$nationality='ir'">
                <xsl:sequence select="'ie'"/>
            </xsl:when>
            <xsl:when test="$nationality='columb'">
                <xsl:sequence select="'co'"/>
            </xsl:when>
            <xsl:when test="$nationality='r'">
                <xsl:sequence select="'ru'"/>
            </xsl:when>
            <xsl:when test="$nationality='øst'">
                <xsl:sequence select="'at'"/>
            </xsl:when>
            <xsl:when test="$nationality='sveit'">
                <xsl:sequence select="'ch'"/>
            </xsl:when>
            <xsl:when test="$nationality='tyrk'">
                <xsl:sequence select="'tr'"/>
            </xsl:when>
            <xsl:when test="$nationality='aserb'">
                <xsl:sequence select="'az'"/>
            </xsl:when>
            <xsl:when test="$nationality='t'">
                <xsl:sequence select="'de'"/>
            </xsl:when>
            <xsl:when test="$nationality='pak'">
                <xsl:sequence select="'pk'"/>
            </xsl:when>
            <xsl:when test="$nationality='iran'">
                <xsl:sequence select="'ir'"/>
            </xsl:when>
            <xsl:when test="$nationality='rwand'">
                <xsl:sequence select="'rw'"/>
            </xsl:when>
            <xsl:when test="$nationality='sudan'">
                <xsl:sequence select="'sd'"/>
            </xsl:when>
            <xsl:when test="$nationality='zimb'">
                <xsl:sequence select="'zw'"/>
            </xsl:when>
            <xsl:when test="$nationality='liby'">
                <xsl:sequence select="'ly'"/>
            </xsl:when>
            <xsl:when test="$nationality='rus'">
                <xsl:sequence select="'ru'"/>
            </xsl:when>
            <xsl:when test="$nationality='russ'">
                <xsl:sequence select="'ru'"/>
            </xsl:when>
            <xsl:when test="$nationality='ukr'">
                <xsl:sequence select="'ua'"/>
            </xsl:when>
            <xsl:when test="$nationality='br'">
                <xsl:sequence select="'br'"/>
            </xsl:when>
            <xsl:when test="$nationality='burm'">
                <xsl:sequence select="'mm'"/>
            </xsl:when>
            <xsl:when test="$nationality='d'">
                <xsl:sequence select="'dk'"/>
            </xsl:when>
            <xsl:when test="$nationality='bosn'">
                <xsl:sequence select="'ba'"/>
            </xsl:when>
            <xsl:when test="$nationality='kin'">
                <xsl:sequence select="'cn'"/>
            </xsl:when>
            <xsl:when test="$nationality='togo'">
                <xsl:sequence select="'tg'"/>
            </xsl:when>
            <xsl:when test="$nationality='bangl'">
                <xsl:sequence select="'bd'"/>
            </xsl:when>
            <xsl:when test="$nationality='indon'">
                <xsl:sequence select="'id'"/>
            </xsl:when>
            <xsl:when test="$nationality='fi'">
                <xsl:sequence select="'fi'"/>
            </xsl:when>
            <xsl:when test="$nationality='isl'">
                <xsl:sequence select="'is'"/>
            </xsl:when>
            <xsl:when test="$nationality='ugand'">
                <xsl:sequence select="'ug'"/>
            </xsl:when>
            <xsl:when test="$nationality='malay'">
                <xsl:sequence select="'my'"/>
            </xsl:when>
            <xsl:when test="$nationality='tanz'">
                <xsl:sequence select="'tz'"/>
            </xsl:when>
            <xsl:when test="$nationality='hait'">
                <xsl:sequence select="'ht'"/>
            </xsl:when>
            <xsl:when test="$nationality='irak'">
                <xsl:sequence select="'iq'"/>
            </xsl:when>
            <xsl:when test="$nationality='am'">
                <xsl:sequence select="'us'"/>
            </xsl:when>
            <xsl:when test="$nationality='viet'">
                <xsl:sequence select="'vn'"/>
            </xsl:when>
            <xsl:when test="$nationality='eng'">
                <xsl:sequence select="'gb'"/>
            </xsl:when>
            <xsl:when test="$nationality='portug'">
                <xsl:sequence select="'pt'"/>
            </xsl:when>
            <xsl:when test="$nationality='dominik'">
                <xsl:sequence select="'do'"/>
            </xsl:when>
            <xsl:when test="$nationality='marok'">
                <xsl:sequence select="'ma'"/>
            </xsl:when>
            <xsl:when test="$nationality='indian'">
                <xsl:sequence select="'in'"/>
            </xsl:when>
            <xsl:when test="$nationality='alb'">
                <xsl:sequence select="'al'"/>
            </xsl:when>
            <xsl:when test="$nationality='syr'">
                <xsl:sequence select="'sy'"/>
            </xsl:when>
            <xsl:when test="$nationality='afg'">
                <xsl:sequence select="'af'"/>
            </xsl:when>
            <xsl:when test="$nationality='trinid'">
                <xsl:sequence select="'tt'"/>
            </xsl:when>
            <xsl:when test="$nationality='est'">
                <xsl:sequence select="'ee'"/>
            </xsl:when>
            <xsl:when test="$nationality='guadel'">
                <xsl:sequence select="'gp'"/>
            </xsl:when>
            <xsl:when test="$nationality='mex'">
                <xsl:sequence select="'mx'"/>
            </xsl:when>
            <xsl:when test="$nationality='egypt'">
                <xsl:sequence select="'eg'"/>
            </xsl:when>
            <xsl:when test="$nationality='chil'">
                <xsl:sequence select="'cl'"/>
            </xsl:when>
            <xsl:when test="$nationality='colomb'">
                <xsl:sequence select="'co'"/>
            </xsl:when>
            <xsl:when test="$nationality='lit'">
                <xsl:sequence select="'lt'"/>
            </xsl:when>
            <xsl:when test="$nationality='sam'">
                <xsl:sequence select="'ws'"/>
            </xsl:when>
            <xsl:when test="$nationality='guatem'">
                <xsl:sequence select="'gt'"/>
            </xsl:when>
            <xsl:when test="$nationality='kor'">
                <xsl:sequence select="'kr'"/>
            </xsl:when>
            <xsl:when test="$nationality='ung'">
                <xsl:sequence select="'hu'"/>
            </xsl:when>
            <xsl:when test="$nationality='rum'">
                <xsl:sequence select="'ro'"/>
            </xsl:when>
            <xsl:when test="$nationality='niger'">
                <xsl:sequence select="'ne'"/>
            </xsl:when>
            <xsl:when test="$nationality='tsj'">
                <xsl:sequence select="'cz'"/>
            </xsl:when>
            <xsl:when test="$nationality='fær'">
                <xsl:sequence select="'fo'"/>
            </xsl:when>
            <xsl:when test="$nationality='jug'">
                <xsl:sequence select="'mk'"/>
            </xsl:when>
            <xsl:when test="$nationality='urug'">
                <xsl:sequence select="'uy'"/>
            </xsl:when>
            <xsl:when test="$nationality='cub'">
                <xsl:sequence select="'cu'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$nationality"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="nlb:parseRole">
        <xsl:param name="role"/>
        <!--
            Note: based on MARC relators
		    (http://lcweb2.loc.gov/diglib/loc.terms/relators/dc-contributor.html)
        -->
        <xsl:variable name="role" select="lower-case($role)"/>
    
        <xsl:choose>
            <xsl:when test="matches($role,'^fr.\s.*') or matches($role,'^til\s.*') or matches($role,'^p.\s.*') or matches($role,'.*(overs|.versett|overatt|omsett).*')">
                <xsl:value-of select="'dc:contributor.translator'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(foto|billed).*')">
                <xsl:value-of select="'dc:contributor.photographer'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(illu|tegning|teikni|tegnet).*')">
                <xsl:value-of select="'dc:contributor.illustrator'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(konsulent|faglig|r.dgiver|research).*')">
                <xsl:value-of select="'dc:contributor.consultant'"/>
            </xsl:when>
            <xsl:when test="matches($role,'reda') or $role='red' or $role='hovedred'">
                <xsl:value-of select="'dc:contributor.secretary'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(redi|bearb|tilrett|edit|eds|instrukt|instruert|revid).*') or $role='ed'">
                <xsl:value-of select="'dc:contributor.editor'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(forord|innl|intro).*')">
                <xsl:value-of select="'dc:creator.foreword'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*etterord.*')">
                <!-- Author of afterword, colophon, etc. -->
                <xsl:value-of select="'dc:creator.afterword'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*noter.*')">
                <!-- Other -->
                <xsl:value-of select="'dc:contributor.other'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*kommentar.*')">
                <!-- Commentator for written text -->
                <xsl:value-of select="'dc:contributor.commentator'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(bidrag|medarb|ansvarl|utgjeve|utgave|medvirk|et\.? al|medf).*')">
                <xsl:value-of select="'dc:contributor'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(lest|fort|presentert).*')">
                <!-- Narrator -->
                <xsl:value-of select="'dc:contributor.narrator'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*regi.*')">
                <!-- Director -->
                <xsl:value-of select="'dc:contributor.director'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*musikk.*')">
                <!-- Musician -->
                <xsl:value-of select="'dc:contributor.musician'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*komponist.*')">
                <!-- Composer -->
                <xsl:value-of select="'dc:contributor.composer'"/>
            </xsl:when>
            <xsl:when test="matches($role,'.*(samlet|utvalg).*')">
                <!-- Compiler -->
                <xsl:value-of select="'dc:contributor.compiler'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'dc:contributor.other'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="nlb:parseDate">
        <xsl:param name="date"/>
        <xsl:choose>
            <xsl:when test="matches($date, $AVAILABLE)">
                <xsl:sequence select="replace($date, $AVAILABLE, '$3-$2-$1')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="nlb:parseBirthDeath">
        <xsl:param name="value"/>
        
        <xsl:variable name="split" select="tokenize($value,'-')"/>
        
        <xsl:choose>
            <xsl:when test="count($split) gt 2">
                <xsl:value-of select="','"/>
                
            </xsl:when>
            <xsl:when test="count($split) = 2">
                <xsl:variable name="sign_death" select="if (matches($split[2],$YEAR_NEGATIVE)) then '-' else ''"/>
                <xsl:variable name="year_death" select="replace($split[2], '^[^\d]*(\d+)([^\d].*)?$', '$1')"/>
                <xsl:variable name="year_death" select="if (matches($year_death,'^\d+$')) then $year_death else ''"/>
                
                <xsl:variable name="sign_birth" select="if (matches($split[1],$YEAR_NEGATIVE)) then '-' else $sign_death"/>
                <xsl:variable name="year_birth" select="replace($split[1], '^[^\d]*(\d+)([^\d].*)?$', '$1')"/>
                <xsl:variable name="year_birth" select="if (matches($year_birth,'^\d+$')) then $year_birth else ''"/>
                
                <xsl:value-of select="concat($sign_birth,$year_birth,',',$sign_death,$year_death)"/>
                
            </xsl:when>
            <xsl:when test="count($split) = 1">
                <xsl:variable name="sign" select="if (matches($split[1],$YEAR_NEGATIVE)) then '-' else ''"/>
                <xsl:variable name="year" select="replace($split[1], '^[^\d]*(\d+)([^\d].*)?$', '$1')"/>
                <xsl:variable name="year" select="if (matches($year,'^\d+$')) then $year else ''"/>
                
                <xsl:value-of select="concat($sign,$year,',')"/>
            </xsl:when>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
