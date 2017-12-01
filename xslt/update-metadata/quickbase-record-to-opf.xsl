<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlbprod="http://www.nlb.no/production"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>

    <xsl:template match="/qdbapi">
        <metadata>
            <xsl:namespace name="dcterms" select="'http://purl.org/dc/terms/'"/>
            <xsl:for-each select="/qdbapi/table/records/record/f">
                <xsl:sort select="@id"/>
                <xsl:apply-templates select="."/>
            </xsl:for-each>
        </metadata>
    </xsl:template>
    
    <xsl:template match="f">
        <xsl:message select="concat('Ingen regel for QuickBase-felt i Record-tabell: ', @id)"/>
    </xsl:template>
    
    <xsl:template match="f[@id='1']">
        <!-- Integer -->
        <meta property="nlbprod:dateCreated">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='2']">
        <!-- Integer -->
        <meta property="nlbprod:dateModified">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='3']">
        <!-- Integer -->
        <meta property="nlbprod:recordId">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='4']">
        <!-- String -->
        <meta property="nlbprod:recordOwner">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='5']">
        <!-- String -->
        <meta property="nlbprod:lastModifiedBy">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='6']">
        <!-- Integer -->
        <meta property="nlbprod:registrationDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='7']">
        <!-- String -->
        <meta property="nlbprod:createdBy">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='8']">
        <!-- String -->
        <meta property="nlbprod:title">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='9']">
        <!-- String -->
        <meta property="nlbprod:author">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='10']">
        <!-- String -->
        <meta property="nlbprod:publisher">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='11']">
        <!-- String -->
        <meta property="nlbprod:originalISBN">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='12']">
        <!-- String -->
        <meta property="nlbprod:productionTurnaroundTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='13']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.epub">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='14']">
        <!-- Boolean -->
        <meta property="nlbprod:epubCatalogued">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='15']">
        <!-- Boolean -->
        <meta property="nlbprod:sourceFileReceived">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='16']">
        <!-- String -->
        <meta property="nlbprod:producer">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='17']">
        <!-- Boolean -->
        <meta property="nlbprod:productionApproved">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='18']">
        <!-- Integer -->
        <meta property="nlbprod:numberOfPages">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='19']">
        <!-- Integer -->
        <meta property="nlbprod:numberOfImages">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='20']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.daisy202">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='21']">
        <!-- String -->
        <meta property="nlbprod:nlbIsbnDaisy202">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='22']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202narrated">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='23']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202tts">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='24']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.daisy202" id="identifier-daisy202student">
            <xsl:value-of select="."/>
        </meta>
        <meta property="nlbprod:dcterms:audience" refines="#identifier-daisy202student">Student</meta>
    </xsl:template>
    
    <xsl:template match="f[@id='25']">
        <!-- String -->
        <meta property="nlbprod:nlbIsbnDaisy202student">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='26']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202narratedStudent">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='27']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202ttsStudent">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='28']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.braille">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='29']">
        <!-- String -->
        <meta property="nlbprod:nlbIsbnBraille">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='30']">
        <!-- Boolean -->
        <meta property="nlbprod:formatBraille">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='31']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.daisy202" id="identifier-daisy202narratedfulltext">
            <xsl:value-of select="."/>
        </meta>
        <meta property="dc:type" refines="#identifier-daisy202narratedfulltext">Narrated Fulltext</meta>
    </xsl:template>
    
    <xsl:template match="f[@id='32']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.ebook">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='33']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202narratedFulltext">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='36']">
        <!-- String -->
        <meta property="nlbprod:nlbIsbnEbook">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='37']">
        <!-- Boolean -->
        <meta property="nlbprod:formatEbook">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='38']">
        <!-- Integer -->
        <meta property="nlbprod:identifier.external">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='40']">
        <!-- Boolean -->
        <meta property="nlbprod:preparedForNarration">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='41']">
        <!-- Boolean -->
        <meta property="nlbprod:daisy202productionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='42']">
        <!-- Boolean -->
        <meta property="nlbprod:daisy202ttsProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='43']">
        <!-- Boolean -->
        <meta property="nlbprod:brailleProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='44']">
        <!-- Boolean -->
        <meta property="nlbprod:ebookProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='46']">
        <!-- Boolean -->
        <meta property="nlbprod:handedOverToNarrator">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='47']">
        <!-- Integer -->
        <meta property="nlbprod:timeForLastChange">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='48']">
        <!-- String -->
        <meta property="nlbprod:lastChangedBy">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='49']">
        <!-- Integer -->
        <meta property="nlbprod:productionsId">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='51']">
        <!-- String -->
        <meta property="nlbprod:commentCatalogization">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='55']">
        <!-- Boolean -->
        <meta property="nlbprod:sourceFileOrdered">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='56']">
        <!-- Integer -->
        <meta property="nlbprod:catalogizationDateEpub">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='58']">
        <!-- String -->
        <meta property="nlbprod:wipsIsbn">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='60']">
        <!-- Boolean -->
        <meta property="nlbprod:forManualPreparationInNLB">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='61']">
        <!-- Integer -->
        <meta property="nlbprod:productionApprovedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='62']">
        <!-- Integer -->
        <meta property="nlbprod:orderDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='63']">
        <!-- String -->
        <meta property="nlbprod:narrator">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='64']">
        <!-- Integer -->
        <meta property="nlbprod:narrationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='65']">
        <!-- Integer -->
        <meta property="nlbprod:handedOverToNarratorDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='66']">
        <!-- String -->
        <meta property="nlbprod:student">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='67']">
        <!-- String -->
        <meta property="nlbprod:genre">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='68']">
        <!-- Boolean -->
        <meta property="nlbprod:narrationComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='69']">
        <!-- Integer -->
        <meta property="nlbprod:narrationCompletionDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='71']">
        <!-- Integer -->
        <meta property="nlbprod:agreedNarrationCompletionDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='73']">
        <!-- Integer -->
        <meta property="nlbprod:preparedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='74']">
        <!-- String -->
        <meta property="nlbprod:producer2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='77']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202wips">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='80']">
        <!-- String -->
        <meta property="nlbprod:addRecord">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='81']">
        <!-- Integer -->
        <meta property="nlbprod:sourceFileOrderedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='82']">
        <!-- Integer -->
        <meta property="nlbprod:sourceFileReceivedOrScannedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='83']">
        <!-- String -->
        <meta property="nlbprod:sourceFileFormat">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='84']">
        <!-- Boolean -->
        <meta property="nlbprod:epubDTBookOrdered">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='85']">
        <!-- Integer -->
        <meta property="nlbprod:daisy202ProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='86']">
        <!-- Integer -->
        <meta property="nlbprod:daisy202ttsProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='87']">
        <!-- Integer -->
        <meta property="nlbprod:brailleProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='88']">
        <!-- Integer -->
        <meta property="nlbprod:ebookProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='97']">
        <!-- Number -->
        <meta property="nlbprod:feeNarratedTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='98']">
        <!-- Number -->
        <meta property="nlbprod:feePreparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='99']">
        <!-- Number -->
        <meta property="nlbprod:additionalFeeNightAndWeekend">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='103']">
        <!-- Number -->
        <meta property="nlbprod:narratedTimeInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='116']">
        <!-- Integer -->
        <meta property="nlbprod:preparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='117']">
        <!-- Integer -->
        <meta property="nlbprod:additionalNightAndWeekend">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='119']">
        <!-- Number -->
        <meta property="nlbprod:preparationTimeInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='120']">
        <!-- Number -->
        <meta property="nlbprod:nightAndWeekendInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='122']">
        <!-- Number -->
        <meta property="nlbprod:sumFee">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='131']">
        <!-- Integer -->
        <meta property="nlbprod:otherWorkForNLB">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='137']">
        <!-- Boolean -->
        <meta property="nlbprod:feeComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='138']">
        <!-- Integer -->
        <meta property="nlbprod:feeCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='139']">
        <!-- Number -->
        <meta property="nlbprod:otherWorkInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='141']">
        <!-- Number -->
        <meta property="nlbprod:advancePayment">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='142']">
        <!-- Number -->
        <meta property="nlbprod:totalSumFee">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='143']">
        <!-- Integer -->
        <meta property="nlbprod:advancePaymentDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='145']">
        <!-- Number -->
        <meta property="nlbprod:feeOtherWork">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='146']">
        <!-- Boolean -->
        <meta property="nlbprod:daisy202readyForLoan">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='147']">
        <!-- Integer -->
        <meta property="nlbprod:daisy202readyForLoanDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='148']">
        <!-- String -->
        <meta property="nlbprod:narrationComment">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='149']">
        <!-- Boolean -->
        <meta property="nlbprod:brailleReadyForLoan">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='150']">
        <!-- Integer -->
        <meta property="nlbprod:brailleReadyForLoanDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='151']">
        <!-- Boolean -->
        <meta property="nlbprod:ebookReadyForLoan">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='152']">
        <!-- Integer -->
        <meta property="nlbprod:EBOOKReadyForLoanDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='153']">
        <!-- String -->
        <meta property="nlbprod:orderFormExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='154']">
        <!-- Boolean -->
        <meta property="nlbprod:dtbookReturned">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='155']">
        <!-- Integer -->
        <meta property="nlbprod:dtbookReturnedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='156']">
        <!-- Integer -->
        <meta property="nlbprod:daisy202ExpectedCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='157']">
        <!-- Integer -->
        <meta property="nlbprod:daisy202studentExpectedCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='158']">
        <!-- Integer -->
        <meta property="nlbprod:brailleExpectedCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='159']">
        <!-- Integer -->
        <meta property="nlbprod:ebookProductionExpectedCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='160']">
        <!-- Integer -->
        <meta property="nlbprod:externalProductionExpectedCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='161']">
        <!-- Integer -->
        <meta property="nlbprod:dueDateForProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='163']">
        <!-- String -->
        <meta property="nlbprod:editingInstructions">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='164']">
        <!-- String -->
        <meta property="nlbprod:translator">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='165']">
        <!-- String -->
        <meta property="nlbprod:language">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='167']">
        <!-- String -->
        <meta property="nlbprod:deliveryControl">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='170']">
        <!-- String -->
        <meta property="nlbprod:category">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='171']">
        <!-- Boolean -->
        <meta property="nlbprod:formatNotes">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='175']">
        <!-- String -->
        <meta property="nlbprod:commentPostProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='176']">
        <!-- Integer -->
        <meta property="nlbprod:playtimeDaisy202">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='177']">
        <!-- Integer -->
        <meta property="nlbprod:playtimeDaisy202tts">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='178']">
        <!-- Boolean -->
        <meta property="nlbprod:formatBrailleClub">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='180']">
        <!-- Boolean -->
        <meta property="nlbprod:notForFee">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='184']">
        <!-- Integer -->
        <meta property="nlbprod:extraPreparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='185']">
        <!-- Number -->
        <meta property="nlbprod:extraPreparationTimeInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='186']">
        <!-- Number -->
        <meta property="nlbprod:feeExtraPreparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='262']">
        <!-- Boolean -->
        <meta property="nlbprod:generateFee">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='268']">
        <!-- Boolean -->
        <meta property="nlbprod:openLinespacing">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='269']">
        <!-- String -->
        <meta property="nlbprod:braillePages">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='270']">
        <!-- String -->
        <meta property="nlbprod:volumes">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='279']">
        <!-- Number -->
        <meta property="nlbprod:rateNarrationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='280']">
        <!-- Number -->
        <meta property="nlbprod:ratePreparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='281']">
        <!-- Number -->
        <meta property="nlbprod:rateExtraPreparationTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='282']">
        <!-- Number -->
        <meta property="nlbprod:rateAdditionalWork">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='285']">
        <!-- Number -->
        <meta property="nlbprod:rateOtherWork">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='286']">
        <!-- String -->
        <meta property="nlbprod:feeModel">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='304']">
        <!-- Boolean -->
        <meta property="nlbprod:generateReceipt">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='308']">
        <!-- Number -->
        <meta property="nlbprod:employeeNumber">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='309']">
        <!-- String -->
        <meta property="nlbprod:account">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='310']">
        <!-- Number -->
        <meta property="nlbprod:costLocation">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='311']">
        <!-- Number -->
        <meta property="nlbprod:overriding">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='312']">
        <!-- Number -->
        <meta property="nlbprod:paymentType">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='314']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionDaisy202">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='315']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionDaisy202tts">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='316']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionBraille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='317']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionEbook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='318']">
        <!-- Boolean -->
        <meta property="nlbprod:singlePagePrint">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='319']">
        <!-- Boolean -->
        <meta property="nlbprod:brailleClubProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='320']">
        <!-- Integer -->
        <meta property="nlbprod:brailleClubProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='321']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionBrailleClub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='323']">
        <!-- String -->
        <meta property="nlbprod:signaturePreparation">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='324']">
        <!-- String -->
        <meta property="nlbprod:signatureDaisy202readyForLoan">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='325']">
        <!-- String -->
        <meta property="nlbprod:signatureEbookReadyForLoan">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='326']">
        <!-- String -->
        <meta property="nlbprod:signatureBrailleReadyForLoan">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='327']">
        <!-- Boolean -->
        <meta property="nlbprod:brailleClubReadyForLoan">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='328']">
        <!-- Integer -->
        <meta property="nlbprod:brailleClubReadyForLoanDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='329']">
        <!-- String -->
        <meta property="nlbprod:signatureBrailleClubReadyForLoan">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='330']">
        <!-- String -->
        <meta property="nlbprod:priceCategory">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='342']">
        <!-- String -->
        <meta property="nlbprod:emailPublisherContact">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='343']">
        <!-- String -->
        <meta property="nlbprod:emailStudent">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='344']">
        <!-- String -->
        <meta property="nlbprod:signatureDTBookOrdered">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='345']">
        <!-- Boolean -->
        <meta property="nlbprod:formatDaisy202externalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='346']">
        <!-- Boolean -->
        <meta property="nlbprod:formatEbookExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='347']">
        <!-- Boolean -->
        <meta property="nlbprod:formatAudioCDWAVExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='348']">
        <!-- Boolean -->
        <meta property="nlbprod:formatAudioCDMP3ExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='349']">
        <!-- Boolean -->
        <meta property="nlbprod:formatOtherExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='350']">
        <!-- String -->
        <meta property="nlbprod:commentExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='351']">
        <!-- Boolean -->
        <meta property="nlbprod:externalProductionProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='352']">
        <!-- Integer -->
        <meta property="nlbprod:externalProductionProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='353']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionExternalProduction">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='354']">
        <!-- Integer -->
        <meta property="nlbprod:playtimeExternalProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='357']">
        <!-- String -->
        <meta property="nlbprod:feeForMultipleNarrators">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='360']">
        <!-- String -->
        <meta property="nlbprod:signatureDeliveredToNarrator">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='362']">
        <!-- Boolean -->
        <meta property="nlbprod:duplicate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='366']">
        <!-- Boolean -->
        <meta property="nlbprod:partialBrailleProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='367']">
        <!-- Boolean -->
        <meta property="nlbprod:formatBraillePartialProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='368']">
        <!-- Boolean -->
        <meta property="nlbprod:formatTactilePrint">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='370']">
        <!-- String -->
        <meta property="nlbprod:commentBraille">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='371']">
        <!-- Boolean -->
        <meta property="nlbprod:tactilePrintReadyForLoan">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='372']">
        <!-- Integer -->
        <meta property="nlbprod:tactilePrintReadyForLoanDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='374']">
        <!-- Boolean -->
        <meta property="nlbprod:tactilePrintProductionComplete">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='375']">
        <!-- Integer -->
        <meta property="nlbprod:tactilePrintProductionCompleteDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='377']">
        <!-- String -->
        <meta property="nlbprod:signatureTactilePrintProductionComplete">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='378']">
        <!-- String -->
        <meta property="nlbprod:signatureTactilePrintReadyForLoan">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='379']">
        <!-- Integer -->
        <meta property="nlbprod:waitingBecauseOfTechnicalProblems">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='380']">
        <!-- Integer -->
        <meta property="nlbprod:inStudioWithProducer">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='381']">
        <!-- Number -->
        <meta property="nlbprod:rateWaitingTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='382']">
        <!-- Number -->
        <meta property="nlbprod:rateInStudioWithProducer">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='383']">
        <!-- Number -->
        <meta property="nlbprod:waitingBecauseOfTechnicalProblemsInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='384']">
        <!-- Number -->
        <meta property="nlbprod:inStudioWithProducerInHours">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='385']">
        <!-- Number -->
        <meta property="nlbprod:compensationWaitingTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='386']">
        <!-- Number -->
        <meta property="nlbprod:compensationInStudioWithProducer">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='387']">
        <!-- String -->
        <meta property="nlbprod:sourceFile">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='388']">
        <!-- String -->
        <meta property="nlbprod:estimatedBookCategory">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='389']">
        <!-- String -->
        <meta property="nlbprod:bookCategory">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='390']">
        <!-- Integer -->
        <meta property="nlbprod:numberOfPages2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='392']">
        <!-- String -->
        <meta property="nlbprod:uploadEpub">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='393']">
        <!-- Boolean -->
        <meta property="nlbprod:productionDelivered">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='395']">
        <!-- Integer -->
        <meta property="nlbprod:productionDeliveryDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='396']">
        <!-- String -->
        <meta property="nlbprod:agency">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='397']">
        <!-- Number -->
        <meta property="nlbprod:productionNumberUID">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='398']">
        <!-- Boolean -->
        <meta property="nlbprod:leaveAMessage">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='399']">
        <!-- String -->
        <meta property="nlbprod:productionQuestionsAndNotes">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='402']">
        <!-- String -->
        <meta property="nlbprod:commentOrder">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='403']">
        <!-- String -->
        <meta property="nlbprod:purchaseOrderId">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='405']">
        <!-- Boolean -->
        <meta property="nlbprod:asciimath">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='406']">
        <!-- String -->
        <meta property="nlbprod:sourceFileFormat2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='407']">
        <!-- String -->
        <meta property="nlbprod:alternateSourceFileURL">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='408']">
        <!-- Boolean -->
        <meta property="nlbprod:exercisesAndAnswers">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='409']">
        <!-- Boolean -->
        <meta property="nlbprod:inlineTextStyling">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='410']">
        <!-- Boolean -->
        <meta property="nlbprod:extractionOfTextContentInImages">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='413']">
        <!-- Boolean -->
        <meta property="nlbprod:productionReturned">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='414']">
        <!-- Integer -->
        <meta property="nlbprod:productionReturnDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='415']">
        <!-- String -->
        <meta property="nlbprod:commentEpubOrder">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='416']">
        <!-- Boolean -->
        <meta property="nlbprod:productionDownloaded">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='417']">
        <!-- Integer -->
        <meta property="nlbprod:downloadedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='418']">
        <!-- String -->
        <meta property="nlbprod:signatureForDownload">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='419']">
        <!-- Integer -->
        <meta property="nlbprod:pages">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='420']">
        <!-- String -->
        <meta property="nlbprod:title2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='421']">
        <!-- String -->
        <meta property="nlbprod:author2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='422']">
        <!-- String -->
        <meta property="nlbprod:contributor">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='423']">
        <!-- String -->
        <meta property="nlbprod:language2">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='426']">
        <!-- String -->
        <meta property="nlbprod:signatureApprovedProduction">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='427']">
        <!-- String -->
        <meta property="nlbprod:signatureReturnedProduction">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='428']">
        <!-- String -->
        <meta property="nlbprod:validationLogFile">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='429']">
        <!-- String -->
        <meta property="nlbprod:originalISSN">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='430']">
        <!-- String -->
        <meta property="nlbprod:volumeNumber">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='431']">
        <!-- String -->
        <meta property="nlbprod:dcSourceUrnIsbn">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='432']">
        <!-- Boolean -->
        <meta property="nlbprod:urgentProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='434']">
        <!-- Number -->
        <meta property="nlbprod:nightAndWeekendPercentageOfTotalTime">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='436']">
        <!-- String -->
        <meta property="nlbprod:signatureFee">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='437']">
        <!-- String -->
        <meta property="nlbprod:signatureRegistration">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='438']">
        <!-- Boolean -->
        <meta property="nlbprod:newRegistration">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='439']">
        <!-- String -->
        <meta property="nlbprod:narratorCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='440']">
        <!-- Number -->
        <meta property="nlbprod:employeeNumberCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='442']">
        <!-- Integer -->
        <meta property="nlbprod:agreedNarrationCompletionDateCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='443']">
        <!-- Boolean -->
        <meta property="nlbprod:handedOverToNarratorCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='444']">
        <!-- Integer -->
        <meta property="nlbprod:handedOverToNarratorDateCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='445']">
        <!-- Boolean -->
        <meta property="nlbprod:generateReceiptCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='446']">
        <!-- String -->
        <meta property="nlbprod:producerCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='447']">
        <!-- Boolean -->
        <meta property="nlbprod:narrationCompleteCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='448']">
        <!-- Integer -->
        <meta property="nlbprod:narrationCompleteDateCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='449']">
        <!-- String -->
        <meta property="nlbprod:feeModelCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='450']">
        <!-- Integer -->
        <meta property="nlbprod:narrationTimeCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='451']">
        <!-- Number -->
        <meta property="nlbprod:narrationTimeInHoursCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='452']">
        <!-- Number -->
        <meta property="nlbprod:rateOtherWorkCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='453']">
        <!-- Number -->
        <meta property="nlbprod:rateExtraPreparationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='454']">
        <!-- Number -->
        <meta property="nlbprod:rateNarrationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='455']">
        <!-- Number -->
        <meta property="nlbprod:ratePreparationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='456']">
        <!-- Number -->
        <meta property="nlbprod:feeOtherWorkCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='457']">
        <!-- Number -->
        <meta property="nlbprod:feeExtraPreparationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='458']">
        <!-- Number -->
        <meta property="nlbprod:feePreparationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='459']">
        <!-- Number -->
        <meta property="nlbprod:feeNarrationCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='461']">
        <!-- Integer -->
        <meta property="nlbprod:inStudioWithProducerCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='462']">
        <!-- Number -->
        <meta property="nlbprod:sumFeeCopy">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='463']">
        <!-- Boolean -->
        <meta property="nlbprod:postProductionStarted">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='464']">
        <!-- Integer -->
        <meta property="nlbprod:postProductionStartedDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='465']">
        <!-- String -->
        <meta property="nlbprod:signaturePostProductionStarted">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='466']">
        <!-- Boolean -->
        <meta property="nlbprod:feeClaimHandled">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='467']">
        <!-- Integer -->
        <meta property="nlbprod:feeClaimHandledDate">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='468']">
        <!-- String -->
        <meta property="nlbprod:signatureFeeClaimHandled">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='469']">
        <!-- String -->
        <meta property="nlbprod:epub3">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='470']">
        <!-- String -->
        <meta property="nlbprod:ebook">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='471']">
        <!-- String -->
        <meta property="nlbprod:daisy202">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='472']">
        <!-- String -->
        <meta property="nlbprod:braille">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='473']">
        <!-- Boolean -->
        <meta property="nlbprod:bokbasen">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='474']">
        <!-- String -->
        <meta property="nlbprod:statusIcon">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='475']">
        <!-- String -->
        <meta property="nlbprod:status">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='476']">
        <!-- Number -->
        <meta property="nlbprod:pricePerPage">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='477']">
        <!-- Number -->
        <meta property="nlbprod:totalPriceForEpubProduction">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='479']">
        <!-- String -->
        <meta property="nlbprod:dcCreator">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>
    
    <xsl:template match="f[@id='record_id']">
        <!-- Integer -->
        <meta property="nlbprod:record_id">
            <xsl:value-of select="."/>
        </meta>
    </xsl:template>

</xsl:stylesheet>
