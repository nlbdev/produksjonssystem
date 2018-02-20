<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for OPF-metadata som skal settes inn i EPUB'ene</title>
    
    <ns prefix="opf" uri="http://www.idpf.org/2007/opf"/>
    <ns prefix="dc" uri="http://purl.org/dc/elements/1.1/"/>
    
    <pattern>
        <title>Boknummer</title>
        <rule context="opf:metadata">
            <assert test="count(dc:identifier[not(@refines)]) = 1">Det må være nøyaktig ett EPUB-boknummer (dc:identifier).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Språk</title>
        <rule context="opf:metadata">
            <assert test="count(dc:language) gt 0">Det må være minst ett språk (dc:language).</assert>
        </rule>
    </pattern>
    
</schema>
