<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                xmlns:issn="urn:issn"
                exclude-result-prefixes="#all"
                version="2.0">
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Calculate the ISSN check digit for 8-digit numbers.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:calc_check_digit" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="check" as="xs:integer*">
            <xsl:analyze-string select="substring(issn:compact($number), 1, 7)" regex="(.)">
                <xsl:matching-substring>
                    <xsl:sequence select="(8 - (position() - 1)) * xs:integer(.)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="check" select="(11 - (sum($check) mod 11)) mod 11"/>
        
        <xsl:value-of select="if ($check ge 10) then 'X' else string($check)"/>
    </xsl:function>
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Calculate the check digit for 10-digit EAN numbers.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:ean_calc_check_digit" as="xs:string">
        <xsl:param name="number" as="xs:string"/>

        <xsl:variable name="check" as="xs:integer*">
            <xsl:analyze-string select="$number" regex="(.)">
                <xsl:matching-substring>
                    <xsl:sequence select="(if (position() mod 2) then 1 else 3) * xs:integer(.)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:value-of select="(10 - (sum($check) mod 10)) mod 10"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert the ISSN to the minimal representation. This strips the number of any valid ISSN separators and removes surrounding whitespace.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:compact" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="normalize-space(replace(upper-case($number), '[^\dX]', ''))"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Reformat the number to the standard presentation format. Both 8 digit ISSNs and 13 digit EANs can be formatted.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:format" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="compact" select="issn:compact($number)"/>
        
        <xsl:choose>
            <xsl:when test="string-length($compact) = 13">
                <xsl:value-of select="replace($compact, '^(.{3})(.{4})(.{3})(.{2})(.{1})$', '$1-$2-$3-$4-$5')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="replace($compact, '^(.{4})(.+)', '$1-$2')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Check if the number provided is a valid ISSN.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:is_valid" as="xs:boolean">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="not(issn:validate($number))"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert the number to EAN-13 format.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:to_ean" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        <xsl:param name="issue_code" as="xs:string?"/> <!-- default if empty: '00' -->
        
        <xsl:variable name="issue_code" select="if ($issue_code) then $issue_code else '00'" as="xs:string"/>
        
        <!--
            The first 3 digits correspond to the 977 prefix assigned to serial publications.
            The next 7 digits correspond to the ISSN (without the hyphen and without the end check digit).
            The 11th and 12th characters are variable and the publisher can use them to express additional information (e.g.; change of price).
            The 13th character is a check digit calculated according to the modulo 10 formula.
        -->
        <xsl:variable name="ean" select="concat('977', substring(issn:compact($number), 1, 7), $issue_code)"/>
        <xsl:variable name="ean" select="concat($ean, issn:ean_calc_check_digit($ean))"/>
        
        <xsl:value-of select="$ean"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert ISSNs in EAN-13 format to the 8 digit format.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:to_issn8" as="xs:string?">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="compact" select="issn:compact($number)"/>
        
        <xsl:choose>
            <xsl:when test="string-length($compact) = 13">
                <xsl:variable name="issn_without_check_digit" select="replace($compact, '^(.{3})(.{4})(.{3})(.{2})(.{1})', '$2$3')"/>
                <xsl:variable name="check_digit" select="issn:calc_check_digit($issn_without_check_digit)"/>
                <xsl:variable name="issn" select="concat($issn_without_check_digit, $check_digit)"/>
                
                <xsl:value-of select="issn:format($issn)"/>
                
            </xsl:when>
            <xsl:when test="string-length($compact) = 8">
                <xsl:value-of select="$number"/>
            </xsl:when>
        </xsl:choose>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Check if the number is a valid ISSN. This checks the length and whether the check digit is correct.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:validate" as="xs:string?">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="compact" select="issn:compact($number)"/>
        
        <xsl:choose>
            <xsl:when test="not(string-length($compact) = 8)">
                <xsl:value-of select="'Invalid length'"/>
            </xsl:when>
            <xsl:when test="not(matches($compact, '^\d{7}[\dX]$'))">
                <xsl:value-of select="'Invalid format'"/>
            </xsl:when>
            <xsl:when test="not(issn:calc_check_digit($compact) = substring($compact, 8, 1))">
                <xsl:value-of select="'Invalid check digit'"/>
            </xsl:when>
        </xsl:choose>
        
        <!-- No return value => valid -->
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Returns a canonical representation of the ISSN. The result is a URN starting with "urn:issn:" and ending with the 8 digit compact version of the ISSN. If the check digit is "X" then the X is rendered in uppercase.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="issn:to_urn" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="concat('urn:issn:', issn:compact(issn:to_issn8($number)))"/>
    </xsl:function>
    
</xsl:stylesheet>