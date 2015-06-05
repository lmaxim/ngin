import argparse
import uuid
import subprocess
import os
import re

# \todo Should be configurable.
kMusetrackerPath = "C:\\Program Files (x86)\\musetracker\\Musetracker.exe"

kGeneratedExtension = "ngininc"

def toCIdentifier( str ):
    result = re.sub( "[^a-zA-Z0-9_]", "_", str )

    # Identifier can't start with a digit, so add an underscore in the front
    # it it does.
    if len( result ) >= 1 and result[0].isdigit():
        result = "_" + result

    return result

def writeData( outPrefix, songs, effects, symbols ):
    outPrefixBase = os.path.basename( outPrefix )

    # \todo Should be able to specify a separate symbol for the song data
    #       as a whole(?) Right now the output prefix is used as the symbol.

    with open( outPrefix + ".s", "w" ) as f:
        f.write( "; Data generated by Ngin musetracker-importer.py\n\n" )

        f.write( '.include "{}.inc"\n\n'.format( outPrefixBase ) )

        f.write( '.segment "CODE"\n\n' )

        f.write( "; Main:\n" )
        f.write( '.include "{}.{}"\n'.format( outPrefixBase,
                                              kGeneratedExtension ) )

        f.write( "\n" )

        # \todo DPCM should be in its own segment to ensure that the DPCM
        #       data is within $C000..$FFFF (assert for that)
        f.write( "; DPCM:\n" )
        f.write( '.include "{}-dpcm.{}"\n'.format( outPrefixBase,
                                                   kGeneratedExtension ) )

        f.write( "\n" )
        f.write( "; Songs:\n" )
        for song in songs:
            f.write( '.include "{}-{}.{}"\n'.format( outPrefixBase, song,
                                                     kGeneratedExtension ) )

        f.write( "\n" )
        f.write( "; Sound effects:\n" )
        for effect in effects:
            f.write( '.include "{}-{}.{}"\n'.format( outPrefixBase, effect,
                                                     kGeneratedExtension ) )

    with open( outPrefix + ".inc", "w" ) as f:
        uniqueSymbol = "NGIN_MUSETRACKER_IMPORTER_" + \
                       str( uuid.uuid4() ).upper().replace( "-", "_" )
        f.write( ".if .not .defined( {} )\n".format( uniqueSymbol ) )
        f.write( "{} = 1\n\n".format( uniqueSymbol ) )
        f.write( '.include "ngin/ngin.inc"\n\n' )

        f.write( ".global {}\n".format( outPrefixBase ) )

        f.write( ".scope {}\n".format( outPrefixBase ) )

        f.write( "    .enum songs\n" )
        for i, song in enumerate( songs ):
            f.write( "        {}\n".format( toCIdentifier( symbols[i] ) ) )
        f.write( "        ; ...\n" )
        f.write( "        kCount\n" )
        f.write( "    .endenum\n" )

        f.write( "    .enum effects\n" )
        for i, effect in enumerate( effects ):
            f.write( "        {}\n".format( toCIdentifier(
                symbols[ i + len( songs ) ] ) ) )
        f.write( "        ; ...\n" )
        f.write( "        kCount\n" )
        f.write( "    .endenum\n" )
        f.write( ".endscope\n" )

        f.write( "\n.endif\n" )

def stripPath( path ):
    return os.path.splitext( os.path.basename( path ) )[ 0 ]

def main():
    argParser = argparse.ArgumentParser(
        description="Import Musetracker songs into Ngin" )

    argParser.add_argument( "-i", "--insong", nargs="*", required=True,
        metavar="SONG" )
    argParser.add_argument( "-e", "--ineffect", nargs="*", required=True,
        metavar="EFFECT" )
    argParser.add_argument( "-s", "--symbol", nargs="*", required=True )
    argParser.add_argument( "-o", "--outprefix", required=True,
        help="prefix for output files", metavar="PREFIX" )

    args = argParser.parse_args()

    if len( args.insong ) + len( args.ineffect ) == 0:
        argParser.error( "at least one input file must be specified" )

    if args.symbol is not None and \
            len( args.insong ) + len( args.ineffect ) != len( args.symbol ):
        argParser.error( "number of infiles must match the number of symbols" )

    # \todo Make sure that there are no matching filenames in the inputs,
    #       and that none of them is named "dpcm" (not allowed due to
    #       limitations of Musetracker export). Have to compare the filename
    #       part only, without extension, and possibly converted to a C symbol.

    # Use a fairly obscure extension to make name collisions less likely.
    musetrackerOutputPrefix = args.outprefix + "." + kGeneratedExtension

    musetrackerArgs = [ kMusetrackerPath, "-s" ] + args.insong + [ "-e" ] \
        + args.ineffect + [ "-o", musetrackerOutputPrefix ]

    musetrackerReturn = subprocess.call( musetrackerArgs )
    # 0 means success.
    # In case of failure it often won't print any kind of error message. :(
    if musetrackerReturn != 0:
        raise Exception( "Musetracker returned non-zero exit code (failure)" )

    baseInSongs   = map( stripPath, args.insong )
    baseInEffects = map( stripPath, args.ineffect )
    writeData( args.outprefix, baseInSongs, baseInEffects, args.symbol )

main()
