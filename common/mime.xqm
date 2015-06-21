xquery version '3.0';

(:~
 : Fold mime-type utility functions.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace mime = 'http://xokomola.com/xquery/common/mime-type';

(:~
 : A map of file extensions to mime-types.
 :
 : List is taken from Ring's mime_type.clj with the addition of a few XML specific
 : mime-types (for XQuery and XSLT).
 :)
declare variable $mime:default-mime-types :=
    map {
        '7z':     'application/x-7z-compressed',
        'aac':    'audio/aac',
        'ai':     'application/postscript',
        'asc':    'text/plain',
        'atom':   'application/atom+xml',
        'avi':    'video/x-msvideo',
        'bin':    'application/octet-stream',
        'bmp':    'image/bmp',
        'bz2':    'application/x-bzip',
        'class':  'application/octet-stream',
        'cer':    'application/pkix-cert',
        'crl':    'application/pkix-crl',
        'crt':    'application/x-x509-ca-cert',
        'css':    'text/css',
        'csv':    'text/csv',
        'deb':    'application/x-deb',
        'dart':   'application/dart',
        'dll':    'application/octet-stream',
        'dmg':    'application/octet-stream',
        'dms':    'application/octet-stream',
        'doc':    'application/msword',
        'dvi':    'application/x-dvi',
        'edn':    'application/edn',
        'eot':    'application/vnd.ms-fontobject',
        'eps':    'application/postscript',
        'etx':    'text/x-setext',
        'exe':    'application/octet-stream',
        'flv':    'video/x-flv',
        'flac':   'audio/flac',
        'gif':    'image/gif',
        'gz':     'application/gzip',
        'htm':    'text/html',
        'html':   'text/html',
        'ico':    'image/x-icon',
        'iso':    'application/x-iso9660-image',
        'jar':    'application/java-archive',
        'jpe':    'image/jpeg',
        'jpeg':   'image/jpeg',
        'jpg':    'image/jpeg',
        'js':     'text/javascript',
        'json':   'application/json',
        'lha':    'application/octet-stream',
        'lzh':    'application/octet-stream',
        'mov':    'video/quicktime',
        'm4v':    'video/mp4',
        'mp3':    'audio/mpeg',
        'mp4':    'video/mp4',
        'mpe':    'video/mpeg',
        'mpeg':   'video/mpeg',
        'mpg':    'video/mpeg',
        'oga':    'audio/ogg',
        'ogg':    'audio/ogg',
        'ogv':    'video/ogg',
        'pbm':    'image/x-portable-bitmap',
        'pdf':    'application/pdf',
        'pgm':    'image/x-portable-graymap',
        'png':    'image/png',
        'pnm':    'image/x-portable-anymap',
        'ppm':    'image/x-portable-pixmap',
        'ppt':    'application/vnd.ms-powerpoint',
        'properties': 'text/plain',
        'ps':     'application/postscript',
        'qt':     'video/quicktime',
        'rar':    'application/x-rar-compressed',
        'ras':    'image/x-cmu-raster',
        'rb':     'text/plain',
        'rd':     'text/plain',
        'rss':    'application/rss+xml',
        'rtf':    'application/rtf',
        'sgm':    'text/sgml',
        'sgml':   'text/sgml',
        'svg':    'image/svg+xml',
        'swf':    'application/x-shockwave-flash',
        'tar':    'application/x-tar',
        'tif':    'image/tiff',
        'tiff':   'image/tiff',
        'ttf':    'application/x-font-ttf',
        'txt':    'text/plain',
        'webm':   'video/webm',
        'wmv':    'video/x-ms-wmv',
        'woff':   'application/font-woff',
        'xbm':    'image/x-xbitmap',
        'xls':    'application/vnd.ms-excel',
        'xml':    'application/xml',
        'xpm':    'image/x-xpixmap',
        'xwd':    'image/x-xwindowdump',
        'zip':    'application/zip',
        (: extra xml types :)
        'xq':     'application/xquery',
        'xqm':    'application/xquery',
        'xquery': 'application/xquery',
        'xsl':    'application/xslt+xml',
        'xslt':   'application/xslt+xml',
        'xlf':    'application/xliff+xml'
    };

(:~
 : Returns the file extension of a filename or filepath.
 :)
declare %private function mime:filename-ext($filename as xs:string)
    as xs:string {
    lower-case(tokenize($filename, '[\./\\]')[last()]) 
};

(:~
 : Get the mime-type from the filename extension. Takes an optional map
 : of extensions to mime-types that overrides values in the default mime-types map.
 :)
declare function mime:ext-mime-type($filename as xs:string, $mime-types as map(*)?)
    as xs:string? {
    let $ext := mime:filename-ext($filename)
    return
        (($mime-types, map {})[1]($ext), $mime:default-mime-types($ext))[1]
};

declare function mime:ext-mime-type($filename as xs:string)
    as xs:string? {
    mime:ext-mime-type($filename, ())
};

(:~
 : Is this a plain text format?
 :)
declare function mime:is-text($filename as xs:string)
    as xs:boolean {
    mime:is-text($filename, map {})
};

declare function mime:is-text($filename as xs:string, $custom as map(*))
    as xs:boolean {
    matches(mime:ext-mime-type($filename, $custom), '^text/.*$')
};

(:~
 : Is this a binary file?
 :
 : TODO: also need to add some binary application/* formats.
 :       maybe check existing open-source projects.
 :)
declare function mime:is-binary($filename as xs:string)
    as xs:boolean {
    matches(mime:ext-mime-type($filename), '^(image|audio|video)/.*$')
};
