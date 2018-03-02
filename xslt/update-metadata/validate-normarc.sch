<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for katalogposter i NORMARC</title>
    
    <ns prefix="SRU" uri="http://www.loc.gov/zing/sru/"/>
    <ns prefix="dc" uri="info:sru/schema/1/dc-v1.1"/>
    <ns prefix="normarc" uri="info:lc/xmlns/marcxchange-v1"/>
    <ns prefix="xsi" uri="http://www.w3.org/2001/XMLSchema-instance"/>
    <ns prefix="DIAG" uri="http://www.loc.gov/zing/sru/diagnostics/"/>
    <ns prefix="marcxchange" uri="info:lc/xmlns/marcxchange-v1"/>
    
    <pattern>
        <title>Format</title>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/starts-with(text(),'1')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('za','c')">Bøker med boknummer som starter med 1 må være markert som punktbok i *019$b ('za' for vanlig, eller 'c' for musikktrykk; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/(starts-with(text(),'2') or starts-with(text(),'6'))]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('dc','dj')">Bøker med boknummer som starter med 2 eller 6 må være markert som lydbok i *019$b ('dc' og/eller 'dj'; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/starts-with(text(),'3')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('la')">Bøker med boknummer som starter med 3 må være markert som e-bok i *019$b ('la', gjerne med 'ga' i tillegg; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/starts-with(text(),'5')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('gt')">Bøker med boknummer som starter med 5 må være markert som EPUB i *019$b ('gt'; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag</title>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/substring(text(),1,1) = ('1','2','3','4','6','7','8','9')]">
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='a']">Utgivelsessted for utgaven må være definert i *260$a</assert>
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='b']">Forlag for utgaven må være definert i *260$b</assert>
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='c']">Utgivelsesår for utgaven må være definert i *260$c</assert>
            <assert test="marcxchange:datafield[@tag='020']/marcxchange:subfield[@code='a']">ISBN for utgaven må være definert i *020$a</assert>
        </rule>
        
        <rule context="marcxchange:datafield[@tag='020']/marcxchange:subfield[@code='a']">
            <assert test="string-length(replace(text(),'[^\d-]','')) gt 0">ISBN i *020$a kan ikke inneholde andre tegn enn tall og bindestrek (var: '<value-of select="text()"/>').</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Originalforlag</title>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/substring(text(),1,1) = ('1','2','3','4','6','7','8','9')]">
            <assert test="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='a']">Utgivelsessted for originalen må være definert i *596$a</assert>
            <assert test="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='b']">Forlag for originalen må være definert i *596$b</assert>
            <assert test="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='c']">Utgivelsesår for originalen må være definert i *596$c</assert>
            <assert test="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">ISBN for originalen må være definert i *596$f</assert>
        </rule>
        
        <rule context="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">
            <assert test="string-length(replace(text(),'[^\d-]','')) gt 0">ISBN i *596$f kan ikke inneholde andre tegn enn tall og bindestrek (var: '<value-of select="text()"/>').</assert>
        </rule>
    </pattern>
    
</schema>
