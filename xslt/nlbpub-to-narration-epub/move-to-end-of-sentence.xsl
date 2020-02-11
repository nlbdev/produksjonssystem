<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:output media-type="xhtml" indent="no" exclude-result-prefixes="#all"/>
    
    <xsl:param name="wrap-sentences" select="'false'"/>
    
    <!-- word characters (matches more than just '\w') from https://stackoverflow.com/a/22075070/281065 -->
    <xsl:variable name="w" select="'\u0041-\u005A\u0061-\u007A\u00AA\u00B5\u00BA\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376\u0377\u037A-\u037D\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u0527\u0531-\u0556\u0559\u0561-\u0587\u05D0-\u05EA\u05F0-\u05F2\u0620-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06E5\u06E6\u06EE\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u08A0\u08A2-\u08AC\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0977\u0979-\u097F\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC\u09DD\u09DF-\u09E1\u09F0\u09F1\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0\u0AE1\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3D\u0B5C\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C33\u0C35-\u0C39\u0C3D\u0C58\u0C59\u0C60\u0C61\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDE\u0CE0\u0CE1\u0CF1\u0CF2\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D60\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32\u0E33\u0E40-\u0E46\u0E81\u0E82\u0E84\u0E87\u0E88\u0E8A\u0E8D\u0E94-\u0E97\u0E99-\u0E9F\u0EA1-\u0EA3\u0EA5\u0EA7\u0EAA\u0EAB\u0EAD-\u0EB0\u0EB2\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10C7\u10CD\u10D0-\u10FA\u10FC-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F4\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u1700-\u170C\u170E-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1877\u1880-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191C\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19C1-\u19C7\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4B\u1B83-\u1BA0\u1BAE\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1CE9-\u1CEC\u1CEE-\u1CF1\u1CF5\u1CF6\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u212F-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2183\u2184\u2C00-\u2C2E\u2C30-\u2C5E\u2C60-\u2CE4\u2CEB-\u2CEE\u2CF2\u2CF3\u2D00-\u2D25\u2D27\u2D2D\u2D30-\u2D67\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2E2F\u3005\u3006\u3031-\u3035\u303B\u303C\u3041-\u3096\u309D-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312D\u3131-\u318E\u31A0-\u31BA\u31F0-\u31FF\u3400-\u4DB5\u4E00-\u9FCC\uA000-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A\uA62B\uA640-\uA66E\uA67F-\uA697\uA6A0-\uA6E5\uA717-\uA71F\uA722-\uA788\uA78B-\uA78E\uA790-\uA793\uA7A0-\uA7AA\uA7F8-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA80-\uAAAF\uAAB1\uAAB5\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAAE0-\uAAEA\uAAF2-\uAAF4\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uABC0-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC'"/>
    
    <!-- whitespace characters (matches more than just '\s') from https://stackoverflow.com/a/28179847/281065 and https://stackoverflow.com/questions/18169006#comment106056977_28179847 -->
    <xsl:variable name="s" select="'\u0009\u000A\u000B\u000C\u000D\u0020\u0085\u00A0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u200B\u200C\u200D\u2028\u2029\u202F\u205F\u2060\u3000\uFEFF'"/>
    
    <!-- uppercase characters (matches more than just '\p{Lu}', which doesn't exist in XPath anyway), or more specifically: all characters with a lower case equivalent (found by using `ord(c) != ord(c.lower())` in Python for all characters between 0x0000 and 0xFFFF) -->
    <xsl:variable name="Lu" select="concat(
        '\u0041-\u005A', (: ABCDEFGHIJKLMNOPQRSTUVWXYZ :)
        '\u00C1-\u00D6', (: ÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ :)
        '\u00D9-\u00DE', (: ÙÚÛÜÝÞ :)
        '\u0102\u0106\u010A\u010E\u0112\u0116\u011A\u011E\u0122\u0126\u012A\u012E\u0132\u0136\u013B\u013F\u0143\u0147\u014C\u0150\u0154\u0158\u015C\u0160\u0164\u0168\u016C\u0170\u0174', (: ĂĆĊĎĒĖĚĞĢĦĪĮĲĶĻĿŃŇŌŐŔŘŜŠŤŨŬŰŴ :)
        '\u0178-\u0179', (: ŸŹ :)
        '\u017D\u0182', (: ŽƂ :)
        '\u0186-\u0187', (: ƆƇ :)
        '\u018A-\u018B', (: ƊƋ :)
        '\u018F-\u0191', (: ƏƐƑ :)
        '\u0194', (: Ɣ :)
        '\u0197-\u0198', (: ƗƘ :)
        '\u019D\u01A0\u01A4\u01A7\u01AC\u01AF', (: ƝƠƤƧƬƯ :)
        '\u01B2-\u01B3', (: ƲƳ :)
        '\u01B7-\u01B8', (: ƷƸ :)
        '\u01C4-\u01C5', (: Ǆǅ :)
        '\u01C8\u01CB\u01CF\u01D3\u01D7\u01DB\u01E0\u01E4\u01E8\u01EC', (: ǈǋǏǓǗǛǠǤǨǬ :)
        '\u01F1-\u01F2', (: Ǳǲ :)
        '\u01F6-\u01F8', (: ǶǷǸ :)
        '\u01FC\u0200\u0204\u0208\u020C\u0210\u0214\u0218\u021C\u0220\u0224\u0228\u022C\u0230', (: ǼȀȄȈȌȐȔȘȜȠȤȨȬȰ :)
        '\u023A-\u023B', (: ȺȻ :)
        '\u023E', (: Ⱦ :)
        '\u0243-\u0246', (: ɃɄɅɆ :)
        '\u024A\u024E\u0372\u037F', (: ɊɎͲͿ :)
        '\u0388-\u038A', (: ΈΉΊ :)
        '\u038E-\u038F', (: ΎΏ :)
        '\u0392-\u03A1', (: ΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡ :)
        '\u03A4-\u03AB', (: ΤΥΦΧΨΩΪΫ :)
        '\u03D8\u03DC\u03E0\u03E4\u03E8\u03EC\u03F4', (: ϘϜϠϤϨϬϴ :)
        '\u03F9-\u03FA', (: ϹϺ :)
        '\u03FE-\u042F', (: ϾϿЀЁЂЃЄЅІЇЈЉЊЋЌЍЎЏАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ :)
        '\u0462\u0466\u046A\u046E\u0472\u0476\u047A\u047E\u048A\u048E\u0492\u0496\u049A\u049E\u04A2\u04A6\u04AA\u04AE\u04B2\u04B6\u04BA\u04BE\u04C1\u04C5\u04C9\u04CD\u04D2\u04D6\u04DA\u04DE\u04E2\u04E6\u04EA\u04EE\u04F2\u04F6\u04FA\u04FE\u0502\u0506\u050A\u050E\u0512\u0516\u051A\u051E\u0522\u0526\u052A\u052E', (: ѢѦѪѮѲѶѺѾҊҎҒҖҚҞҢҦҪҮҲҶҺҾӁӅӉӍӒӖӚӞӢӦӪӮӲӶӺӾԂԆԊԎԒԖԚԞԢԦԪԮ :)
        '\u0532-\u0556', (: ԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖ :)
        '\u10A1-\u10C5', (: ႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅ :)
        '\u10CD', (: Ⴭ :)
        '\u13A1-\u13F5', (: ᎡᎢᎣᎤᎥᎦᎧᎨᎩᎪᎫᎬᎭᎮᎯᎰᎱᎲᎳᎴᎵᎶᎷᎸᎹᎺᎻᎼᎽᎾᎿᏀᏁᏂᏃᏄᏅᏆᏇᏈᏉᏊᏋᏌᏍᏎᏏᏐᏑᏒᏓᏔᏕᏖᏗᏘᏙᏚᏛᏜᏝᏞᏟᏠᏡᏢᏣᏤᏥᏦᏧᏨᏩᏪᏫᏬᏭᏮᏯᏰᏱᏲᏳᏴᏵ :)
        '\u1E02\u1E06\u1E0A\u1E0E\u1E12\u1E16\u1E1A\u1E1E\u1E22\u1E26\u1E2A\u1E2E\u1E32\u1E36\u1E3A\u1E3E\u1E42\u1E46\u1E4A\u1E4E\u1E52\u1E56\u1E5A\u1E5E\u1E62\u1E66\u1E6A\u1E6E\u1E72\u1E76\u1E7A\u1E7E\u1E82\u1E86\u1E8A\u1E8E\u1E92\u1E9E\u1EA2\u1EA6\u1EAA\u1EAE\u1EB2\u1EB6\u1EBA\u1EBE\u1EC2\u1EC6\u1ECA\u1ECE\u1ED2\u1ED6\u1EDA\u1EDE\u1EE2\u1EE6\u1EEA\u1EEE\u1EF2\u1EF6\u1EFA\u1EFE', (: ḂḆḊḎḒḖḚḞḢḦḪḮḲḶḺḾṂṆṊṎṒṖṚṞṢṦṪṮṲṶṺṾẂẆẊẎẒẞẢẦẪẮẲẶẺẾỂỆỊỎỒỖỚỞỢỦỪỮỲỶỺỾ :)
        '\u1F09-\u1F0F', (: ἉἊἋἌἍἎἏ :)
        '\u1F19-\u1F1D', (: ἙἚἛἜἝ :)
        '\u1F29-\u1F2F', (: ἩἪἫἬἭἮἯ :)
        '\u1F39-\u1F3F', (: ἹἺἻἼἽἾἿ :)
        '\u1F49-\u1F4D', (: ὉὊὋὌὍ :)
        '\u1F5B\u1F5F', (: ὛὟ :)
        '\u1F69-\u1F6F', (: ὩὪὫὬὭὮὯ :)
        '\u1F89-\u1F8F', (: ᾉᾊᾋᾌᾍᾎᾏ :)
        '\u1F99-\u1F9F', (: ᾙᾚᾛᾜᾝᾞᾟ :)
        '\u1FA9-\u1FAF', (: ᾩᾪᾫᾬᾭᾮᾯ :)
        '\u1FB9-\u1FBC', (: ᾹᾺΆᾼ :)
        '\u1FC9-\u1FCC', (: ΈῊΉῌ :)
        '\u1FD9-\u1FDB', (: ῙῚΊ :)
        '\u1FE9-\u1FEC', (: ῩῪΎῬ :)
        '\u1FF9-\u1FFC', (: ΌῺΏῼ :)
        '\u212A-\u212B', (: KÅ :)
        '\u2160-\u216F', (: ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫⅬⅭⅮⅯ :)
        '\u24B6-\u24CF', (: ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ :)
        '\u2C01-\u2C2E', (: ⰁⰂⰃⰄⰅⰆⰇⰈⰉⰊⰋⰌⰍⰎⰏⰐⰑⰒⰓⰔⰕⰖⰗⰘⰙⰚⰛⰜⰝⰞⰟⰠⰡⰢⰣⰤⰥⰦⰧⰨⰩⰪⰫⰬⰭⰮ :)
        '\u2C62-\u2C64', (: ⱢⱣⱤ :)
        '\u2C69', (: Ⱪ :)
        '\u2C6D-\u2C70', (: ⱭⱮⱯⱰ :)
        '\u2C75', (: Ⱶ :)
        '\u2C7F-\u2C80', (: ⱿⲀ :)
        '\u2C84\u2C88\u2C8C\u2C90\u2C94\u2C98\u2C9C\u2CA0\u2CA4\u2CA8\u2CAC\u2CB0\u2CB4\u2CB8\u2CBC\u2CC0\u2CC4\u2CC8\u2CCC\u2CD0\u2CD4\u2CD8\u2CDC\u2CE0\u2CEB\u2CF2\uA642\uA646\uA64A\uA64E\uA652\uA656\uA65A\uA65E\uA662\uA666\uA66A\uA680\uA684\uA688\uA68C\uA690\uA694\uA698\uA722\uA726\uA72A\uA72E\uA734\uA738\uA73C\uA740\uA744\uA748\uA74C\uA750\uA754\uA758\uA75C\uA760\uA764\uA768\uA76C\uA779', (: ⲄⲈⲌⲐⲔⲘⲜⲠⲤⲨⲬⲰⲴⲸⲼⳀⳄⳈⳌⳐⳔⳘⳜⳠⳫⳲꙂꙆꙊꙎꙒꙖꙚꙞꙢꙦꙪꚀꚄꚈꚌꚐꚔꚘꜢꜦꜪꜮꜴꜸꜼꝀꝄꝈꝌꝐꝔꝘꝜꝠꝤꝨꝬꝹ :)
        '\uA77D-\uA77E', (: ꝽꝾ :)
        '\uA782\uA786\uA78D\uA792\uA798\uA79C\uA7A0\uA7A4\uA7A8', (: ꞂꞆꞍꞒꞘꞜꞠꞤꞨ :)
        '\uA7AB-\uA7AE', (: ꞫꞬꞭꞮ :)
        '\uA7B1-\uA7B4', (: ꞱꞲꞳꞴ :)
        '\uFF21-\uFF3A' (: ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ :)
    )"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- matches an element with a non-empty text node -->
    <xsl:template match="*[text()[normalize-space()]]">
        <xsl:for-each-group select="node()" group-ending-with=".[self::*[f:has-sentence-ending(.)]]">  <!-- NOTE: this is just for running XSpec in oXygen 17. Should be safe to replace with ".[f:has-sentence-ending(.)]". See: https://saxonica.plan.io/issues/1812 -->
            <xsl:variable name="sentence-content" select="current-group()[f:has-sentence-content(.)]/(. | following-sibling::node()) intersect current-group()"/>
            
            <!-- content between (before) sentences -->
            <xsl:apply-templates select="current-group() except $sentence-content"/>
            
            <xsl:choose>
                <xsl:when test="$sentence-content[self::text()]">
                    <span epub:type="z3998:sentence">
                        <xsl:apply-templates select="current-group()"/>  <!-- wrap as sentence -->
                    </span>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="current-group()"/>  <!-- we'll handle this deeper down in the document instead -->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:function name="f:has-sentence-content" as="xs:boolean">
        <xsl:param name="context" as="node()"/>
        
        <xsl:value-of select="exists($context/descendant-or-self::text()[normalize-space()])"/>
    </xsl:function>
    
    <xsl:function name="f:has-sentence-ending" as="xs:boolean">
        <xsl:param name="context" as="node()"/>
        
        <xsl:choose>
            <xsl:when test="$context/self::text()">
                <xsl:value-of select="matches($context, concat('[.!?‽][^', $w, $s, ']*', $s, '+[^', $w, $s, ']*', $Lu))"/>
            </xsl:when>
            <xsl:when test="$context/self::*">
                <xsl:value-of select="exists($context/node()[f:has-sentence-ending(.)])"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>