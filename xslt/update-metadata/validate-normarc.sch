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
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('za','c')">Bøker med boknummer som starter med 1 må være markert som punktbok i *019$b ('za' for vanlig, eller 'c' for musikktrykk).</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/(starts-with(text(),'2') or starts-with(text(),'6'))]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('dc','dj')">Bøker med boknummer som starter med 2 eller 6 må være markert som lydbok i *019$b ('dc' og/eller 'dj').</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/starts-with(text(),'3')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('la')">Bøker med boknummer som starter med 3 må være markert som e-bok i *019$b ('la', gjerne med 'ga' i tillegg).</assert>
        </rule>
        
        <rule context="marcxchange:record[marcxchange:controlfield[@tag='001']/starts-with(text(),'5')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('gt')">Bøker med boknummer som starter med 5 må være markert som EPUB i *019$b ('gt').</assert>
        </rule>
    </pattern>
    
</schema>
