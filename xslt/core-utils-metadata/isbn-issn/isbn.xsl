<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                xmlns:isbn="urn:isbn"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:variable name="isbn-ranges" select="document('isbn-ranges.xml')/*" as="element()"/>
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Calculate the check digit for 10-digit ISBNs. Must be either the first 9 digits without the check digit, or all 10 digits including the check digit.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:calc_isbn10_check_digit" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="check" as="xs:integer*">
            <xsl:analyze-string select="substring(isbn:clean($number), 1, 9)" regex="(.)">
                <xsl:matching-substring>
                    <xsl:sequence select="(10 - (position() - 1)) * xs:integer(.)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="check" select="(11 - (sum($check) mod 11)) mod 11"/>
        
        <xsl:value-of select="if ($check ge 10) then 'X' else string($check)"/>
    </xsl:function>
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Calculate the check digit for EAN numbers. Automatically removes 10th digit for 10 digit ISBNs and 13th digit for 13 digit ISBNs.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:ean_calc_check_digit" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="compact" select="isbn:compact($number, false())"/>
        <xsl:variable name="compact-without-check-digit" select="if (string-length($compact) = 10) then substring($compact, 1, 9) else substring($compact, 1, 12)"/>
        
        <xsl:variable name="check" as="xs:integer*">
            <xsl:analyze-string select="$compact-without-check-digit" regex="(.)">
                <xsl:matching-substring>
                    <xsl:sequence select="(if (position() mod 2) then 1 else 3) * xs:integer(.)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:value-of select="(10 - (sum($check) mod 10)) mod 10"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert the ISBN to the minimal representation. This strips the number of any valid ISBN separators and removes surrounding whitespace. If the covert parameter is True the number is also converted to ISBN-13 format.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:compact" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        <xsl:param name="convert" as="xs:boolean?"/> <!-- default: false() -->
        
        <xsl:variable name="number" select="isbn:clean($number)"/>
        <xsl:variable name="number" select="if (string-length($number) = 9) then concat('0', $number) else $number"/>
        <xsl:variable name="number" select="if ($convert) then isbn:to_isbn13($number) else $number"/>
        
        <xsl:value-of select="$number"/>
    </xsl:function>
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>This strips the number of any valid ISBN separators and removes surrounding whitespace.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:clean" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="normalize-space(replace(upper-case($number), '[^\dX]', ''))"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Reformat the number to the standard presentation format with the EAN.UCC prefix (if any), the group prefix, the registrant, the item number and the check-digit separated (if possible) by the specified separator. Passing an empty separator should equal compact() though this is less efficient. If the covert parameter is True the number is converted to ISBN-13 format first.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:format" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        <xsl:param name="separator" as="xs:string?"/> <!-- default: '-' -->
        <xsl:param name="convert" as="xs:boolean?"/> <!-- default: false() -->
        
        <xsl:variable name="separator" select="if ($separator) then $separator else '-'"/>
        
        <xsl:variable name="parts" select="isbn:split($number, $convert)" as="xs:string*"/>
        
        <xsl:value-of select="string-join((for $part in ($parts) return if ($part) then $part else ()), $separator)"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Check if the number provided is a valid ISBN (either a legacy 10-digit one or a 13-digit one). This checks the length and the check bit but does not check if the group and publisher are valid (use split() for that).</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:is_valid" as="xs:boolean">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="not(isbn:validate($number))"/>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Check the passed number and return ‘ISBN13’, ‘ISBN10’ or nothing (for invalid) for checking the type of number passed.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:isbn_type" as="xs:string?">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:if test="isbn:is_valid($number)">
            <xsl:choose>
                <xsl:when test="string-length(isbn:compact($number, false())) = 10">
                    <xsl:value-of select="'ISBN10'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'ISBN13'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Split the specified ISBN into an EAN.UCC prefix, a group prefix, a registrant, an item number and a check-digit. If the number is in ISBN-10 format the returned EAN.UCC prefix is an empty string. If the convert parameter is True the number is converted to ISBN-13 format first.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:split" as="xs:string*">
        <xsl:param name="number" as="xs:string"/>
        <xsl:param name="convert" as="xs:boolean?"/> <!-- default: false() -->
        
        <!--
            ISBN anatomy:
            1. EAN.UCC prefix
            2. Registration group prefix
            3. Registrant
            4. Publication / item number
            5. Check digit
        -->
        
        <xsl:variable name="compact" select="isbn:compact($number, $convert)" as="xs:string"/>
        <xsl:variable name="digits" select="string-length($compact)"/>
        <xsl:variable name="compact" select="if ($digits = 10) then concat('978', $compact) else $compact"/>
        
        <xsl:variable name="ean-prefix" select="if ($digits = 13) then substring($compact, 1, 3) else ''"/>
        <xsl:variable name="check-digit" select="substring($compact, 13, 1)"/>
        
        <xsl:variable name="remainder" select="substring($compact, 4, 9)"/>
        
        <xsl:variable name="range-group" as="element()?" select="$isbn-ranges/RegistrationGroups/Group[starts-with($compact, replace(Prefix/text(),'-',''))]"/>
        <xsl:choose>
           <xsl:when test="$range-group">
               <xsl:variable name="registration-group" select="substring-after($range-group/Prefix/text(), '-')"/>
               <xsl:variable name="remainder" select="substring($remainder, string-length($registration-group) + 1)"/>
               <xsl:variable name="position-in-range" select="xs:integer(substring(concat($remainder, '0000000'), 1, 7))" as="xs:integer"/> <!-- max 7 digits from remainder, pad with zeros if less than 7 digits -->
               
               <xsl:variable name="rule" as="element()?" select="$range-group/Rules/Rule[xs:integer(tokenize(Range/text(),'-')[1]) le $position-in-range and $position-in-range le xs:integer(tokenize(Range/text(),'-')[2])]"/>
               <xsl:choose>
                   <xsl:when test="$rule">
                       <xsl:variable name="split-position" select="$rule/Length/text()" as="xs:integer"/>
                       <xsl:variable name="registrant" select="substring(string($remainder), 1, $split-position)"/>
                       <xsl:variable name="publication" select="substring(string($remainder), $split-position + 1)"/>
                       
                       <xsl:sequence select="($ean-prefix, $registration-group, $registrant, $publication, $check-digit)"/>
                   </xsl:when>
                   <xsl:otherwise>
                       <!-- no registrant range rule found -->
                       <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                   </xsl:otherwise>
               </xsl:choose>
           </xsl:when>
            <xsl:otherwise>
                <!-- no registration group found, try some heuristics for extracting registration group -->
                <xsl:choose>
                    <xsl:when test="$ean-prefix = ('', '978')">
                        <xsl:choose>
                            <xsl:when test="substring($remainder, 1, 1) = ('0', '1', '2', '3', '4', '5', '7')">
                                <!-- ISBNs starting with 0, 1, 2, 3, 4, 5 or 7 have one digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 1)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 2)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:when test="substring($remainder, 1, 1) = ('6', '8')">
                                <!-- ISBNs starting with 6 or 8 have two digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 2)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 3)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:when test="substring($remainder, 1, 2) = ('90', '91', '92', '93', '94')">
                                <!-- ISBNs starting with 90, 91, 92, 93 or 94 have two digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 2)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 3)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:when test="substring($remainder, 1, 2) = ('95', '96', '97', '98')">
                                <!-- ISBNs starting with 95, 96, 97 or 98 have three digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 3)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 4)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:when test="substring($remainder, 1, 3) = ('991', '992', '993', '994', '995', '996', '997', '998')">
                                <!-- ISBNs starting with 991, 992, 993, 994, 995, 996, 997 or 998 have four digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 4)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 5)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:when test="substring($remainder, 1, 3) = ('999')">
                                <!-- ISBNs starting with 999 have five digit registration groups -->
                                <xsl:variable name="registration-group" select="substring($remainder, 1, 5)"/>
                                <xsl:variable name="remainder" select="substring($remainder, 6)"/>
                                
                                <xsl:sequence select="($ean-prefix, $registration-group, '', $remainder, $check-digit)"/>
                            </xsl:when>
                            
                            <xsl:otherwise>
                                <xsl:sequence select="($ean-prefix, '', '', $remainder, $check-digit)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:sequence select="($ean-prefix, '', '', $remainder, $check-digit)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert the number to ISBN-10 format.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:to_isbn10" as="xs:string?">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="clean" select="isbn:clean($number)"/>
        
        <xsl:choose>
            <xsl:when test="string-length($clean) = 10">
                <xsl:value-of select="$number"/>
            </xsl:when>
            <xsl:when test="not(isbn:is_valid($number))">
                <!-- return empty sequence -->
            </xsl:when>
            <xsl:when test="not(substring($clean, 1, 3) = '978')">
                <!-- Does not use 978 Bookland prefix. Return empty sequence. -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="compact" select="isbn:compact($number, ())"/>
                
                <xsl:variable name="compact_isbn10_without_check_digit" select="substring($compact, 4, 9)"/>
                <xsl:variable name="check_digit_isbn10" select="isbn:calc_isbn10_check_digit($compact_isbn10_without_check_digit)"/>
                
                <xsl:variable name="separator" select="if (contains($number, ' ')) then ' ' else if (contains($number, '-')) then '-' else ''"/>
                
                <xsl:variable name="number_without_check_digit" select="normalize-space($number)"/> <!-- remove surrounding whitespace -->
                <xsl:variable name="number_without_check_digit" select="substring($number_without_check_digit, 4)"/> <!-- remove Bookland prefix (first three numbers) -->
                <xsl:variable name="number_without_check_digit" select="replace($number_without_check_digit, '(^[^\d]+|[^\dX]+$)', '')"/> <!-- remove surrounding separators -->
                <xsl:variable name="number_without_check_digit" select="substring($number_without_check_digit, 1, string-length($number_without_check_digit) - 1)"/> <!-- remove check digit -->
                <xsl:variable name="number_without_check_digit" select="normalize-space($number_without_check_digit)"/> <!-- remove surrounding whitespace -->
                
                <xsl:value-of select="replace(string-join(($number_without_check_digit, $check_digit_isbn10), $separator), '([^0-9X])[^0-9X]+', '$1')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Convert the number to ISBN-13 format.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:to_isbn13" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="clean" select="isbn:clean($number)"/>
        
        <xsl:choose>
            <xsl:when test="string-length($clean) = 13">
                <xsl:value-of select="$number"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="compact" select="isbn:compact($number, ())"/>
                
                <!-- use compact representation if it's not the same as the clean representation (i.e. when 9 digit ISBNs are prefixed with 0) -->
                <xsl:variable name="number" select="if (string-length($clean) != string-length($compact)) then $compact else $number"/>
                
                <xsl:variable name="compact_isbn13_without_check_digit" select="concat('978', substring($compact, 1, 9))"/>
                <xsl:variable name="check_digit_isbn13" select="isbn:ean_calc_check_digit($compact_isbn13_without_check_digit)"/>
                
                <xsl:variable name="separator" select="if (contains($number, ' ')) then ' ' else if (contains($number, '-')) then '-' else ''"/>
                
                <xsl:variable name="number_without_check_digit" select="normalize-space($number)"/>
                <xsl:variable name="number_without_check_digit" select="substring($number_without_check_digit, 1, string-length($number_without_check_digit) - 1)"/>
                
                <xsl:value-of select="replace(string-join(('978', $number_without_check_digit, $check_digit_isbn13), $separator), '([^0-9X])[^0-9X]+', '$1')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Check if the number provided is a valid ISBN (either a legacy 10-digit one or a 13-digit one). This checks the length and the check bit but does not check if the group and publisher are valid (use split() for that).</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:validate" as="xs:string?">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:variable name="compact" select="isbn:compact($number, false())"/>
        
        <xsl:choose>
            <xsl:when test="string-length($compact) = 10">
                <xsl:choose>
                    <xsl:when test="not(matches($compact, '^\d{9}[\dX]$'))">
                        <xsl:value-of select="'Invalid format'"/>
                    </xsl:when>
                    <xsl:when test="not(isbn:calc_isbn10_check_digit($compact) = substring($compact, 10, 1))">
                        <xsl:value-of select="'Invalid check digit'"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:when>
            
            <xsl:when test="string-length($compact) = 13">
                <xsl:choose>
                    <xsl:when test="not(matches($compact, '^\d{13}$'))">
                        <xsl:value-of select="'Invalid format'"/>
                    </xsl:when>
                    <xsl:when test="not(isbn:ean_calc_check_digit($compact) = substring($compact, 13, 1))">
                        <xsl:value-of select="'Invalid check digit'"/>
                    </xsl:when>
                    <xsl:when test="not(substring($compact, 1, 3) = ('978', '979'))">
                        <xsl:value-of select="'Invalid component'"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:value-of select="'Invalid length'"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <!-- No return value => valid -->
    </xsl:function>
    
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>Returns a canonical representation of the ISBN. The result is a URN starting with "urn:isbn:" and ending with the 13 digit compact version of the ISBN.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="isbn:to_urn" as="xs:string">
        <xsl:param name="number" as="xs:string"/>
        
        <xsl:value-of select="concat('urn:isbn:', isbn:compact($number, true()))"/>
    </xsl:function>
    
</xsl:stylesheet>