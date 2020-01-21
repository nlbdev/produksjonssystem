<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <!--
        This stylesheet inserts some newlines and indentation where they are useful,
        but otherwise leaves the document as is.
    -->
    
    <xsl:output indent="no" method="xhtml" omit-xml-declaration="no" include-content-type="no" exclude-result-prefixes="#all"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!--
        Block elements, according to: https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements
        Also added some extras.
    -->
    <xsl:template match="*[f:is-block(.)]">
        
        <xsl:if test="not(exists(preceding-sibling::node())) or exists(preceding-sibling::node()[1] intersect preceding-sibling::*[1])">
            <!-- no preceding siblings, or first preceding sibling node is a element -->
            <xsl:text>
</xsl:text>
        </xsl:if>
        
        <xsl:variable name="current-indentation" select="if (not(exists(preceding-sibling::node())) or exists(preceding-sibling::node()[1] intersect preceding-sibling::*[1])) then 0 else
                                                         (preceding-sibling::node()[1][self::text()]/string-length(tokenize(., '\n')[last()]), 1000)[1]"/>
        <xsl:for-each select="$current-indentation + 1 to count(ancestor::*) * 4">
            <xsl:text> </xsl:text>
        </xsl:for-each>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="exists(node())">
                <xsl:apply-templates select="node()"/>
                
                <xsl:choose>
                    <xsl:when test="exists(*[not(f:is-block(.))]) or exists(text()[normalize-space()])">
                        <!-- there exists a non-inline element or a non-empty text node, don't do any more indentation inside here -->
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- make sure closing tag of block element is properly indented -->
                        <xsl:variable name="last-text-node-lines" select="node()[last()][self::text()]" as="xs:string?"/>
                        <xsl:variable name="last-text-node-lines" select="if ($last-text-node-lines) then tokenize($last-text-node-lines, '\n') else ('')" as="xs:string+"/>
                        <xsl:if test="count($last-text-node-lines) = 1">
                            <xsl:text>
</xsl:text>
                        </xsl:if>
                        <xsl:variable name="current-indentation" select="string-length($last-text-node-lines[last()])"/>
                        <xsl:for-each select="$current-indentation + 1 to count(ancestor::*) * 4">
                            <xsl:text> </xsl:text>
                        </xsl:for-each>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:copy>
        
        <!--<xsl:if test="exists(parent::*) and not(exists(following-sibling::node() except (following-sibling::text()[not(normalize-space())] | following-sibling::comment())))">
            <!-\- has a parent but there is no following siblings or following siblings consist only of whitespace and/or comments -\->
            <xsl:call-template name="indent">
                <xsl:with-param name="indent" select="count(ancestor::*) - 1"/>
            </xsl:call-template>
        </xsl:if>-->
        
    </xsl:template>
    
    <!-- try to break up long paragraphs (doesn't handle inline elements) -->
    <xsl:template match="p/text()[normalize-space() and not(ancestor::*/@xml:space = 'preserve') and not(ancestor::pre | ancestor::code)]">
        <xsl:variable name="preceding-space" select="matches(., '^\s')" as="xs:boolean"/>
        <xsl:variable name="trailing-space" select="matches(., '\s$')" as="xs:boolean"/>
        <xsl:variable name="words" select="tokenize(normalize-space(.), '\s+')" as="xs:string*"/>
        <xsl:variable name="indent" select="count(ancestor::*)" as="xs:integer"/>
        
        <xsl:if test="$preceding-space">
            <xsl:text> </xsl:text>
        </xsl:if>
        
        <xsl:for-each select="$words">
            <xsl:value-of select="."/>
            
            <xsl:if test="not(position() = last())">
                <xsl:text> </xsl:text>
            </xsl:if>
            
            <xsl:if test="position() mod 15 = 0">
                <xsl:call-template name="indent">
                    <xsl:with-param name="indent" select="$indent"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:for-each>
        
        <xsl:if test="$trailing-space">
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>
    
    <!-- utility template for indentation -->
    <xsl:template name="indent">
        <xsl:param name="indent" as="xs:integer"/>
        <xsl:param name="newline" as="xs:boolean" select="true()"/>
        
        <xsl:if test="$newline">
            <xsl:text>
</xsl:text>
        </xsl:if>

        
        <xsl:for-each select="1 to $indent">
            <xsl:text>    </xsl:text>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:function name="f:is-block" as="xs:boolean">
        <xsl:param name="context" as="element()"/>
        
        <xsl:choose>
            <!-- Block elements, according to: https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements -->
            <xsl:when test="$context[self::address | self::article | self::aside | self::blockquote | self::details | self::dialog |
                                     self::dd | self::div | self::dl | self::dt | self::fieldset | self::figcaption | self::figure |
                                     self::footer | self::form | self::h1 | self::h2 | self::h3 | self::h4 | self::h5 | self::h6 |
                                     self::header | self::hgroup | self::hr | self::li | self::main | self::nav | self::ol | self::p |
                                     self::pre | self::section | self::table | self::ul]">
                <xsl:sequence select="true()"/>
            </xsl:when>
            
            <!-- Some other elements to be considered as block elements. -->
            <xsl:when test="$context[self::html | self::head | self::body | self::img[parent::figure]]">
                <xsl:sequence select="true()"/>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:sequence select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>