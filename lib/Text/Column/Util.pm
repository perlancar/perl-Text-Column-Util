package Text::Column::Util;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Utilities for displaying text in multiple columns',
};

# TODO: color theme

our %args_common = (
    show_linum => {
        summary => 'Show line number',
        schema => 'bool*',
    },
    linum_width => {
        summary => 'Line number width',
        schema => 'posint*',
    },
    separator => {
        summary => 'Separator character between columns',
        schema => 'str*',
        default => '|',
    },
    on_long_line => {
        summary => 'What to do to long lines',
        schema => ['str*', in=>['clip','wrap']],
        default => 'clip',
        cmdline_aliases => {
            wrap => {summary=>"Shortcut for --on-long-line=wrap", is_flag=>1, code=>sub { $_[0]{on_long_line} = 'wrap' }},
            #clip => {summary=>"Shortcut for --on-long-line=clip", is_flag=>1, code=>sub { $_[0]{on_long_line} = 'clip' }},
        },
    },
    # TODO: column_widths
    # TODO: column_bgcolors
    # TODO: column_fgcolors
);

our %argopt_num_columns = (
    num_columns => {
        schema => 'posint*',
        summary => 'Required if you use _gen_texts instead of texts',
    },
);

$SPEC{combine_texts_in_columns} = {
    v => 1.1,
    summary => 'Combine texts into columns',
    args => {
        %args_common,
        %argopt_num_columns,
        texts => {
            schema => ['array*', of=>'str*'],
        },
        gen_texts => {
            schema => 'code*',
        },
    },
    args_rels => {
        req_one => ['texts', 'gen_texts'],
    },
};
sub combine_texts_in_columns {
    require Term::App::Util::Size;
    require Text::ANSI::WideUtil;

    my %args = @_;
    my $texts = $args{texts};
    my $num_columns = $args{num_columns} // @$texts;
    return [412, "Please provide 'texts' or 'num_columns'"] unless $num_columns;
    my $on_long_line = $args{on_long_line} // 'clip';

    # calculate widths

    my $term_width0 = Term::App::Util::Size::term_width()->[2];
    my $term_width = $term_width0;
    my $separator = $args{separator} // '|';
    my $separator_width = Text::WideChar::Util::mbswidth($separator);
    my $show_linum = $args{show_linum};
    my $linum_width = $args{linum_width} // 4;
    if ($show_linum) {
        $term_width0 > $linum_width + $separator_width
            or return [412, "No horizontal room for line number"];
        $term_width -= $linum_width + $separator_width;
    }
    my $linum_fmt = "%${linum_width}d";
    $term_width > $separator_width * ($num_columns-1)
        or return [412, "No horizontal room for separators"];
    $term_width -= $separator_width * ($num_columns-1);

    my $column_width = int($term_width / $num_columns);
    $column_width > 1 or return [412, "No horizontal room for the columns"];
    #log_trace "column_width is $column_width";

    $texts = $args{_gen_texts}->() if $args{_gen_texts};

    # split each text into lines
    my @text_lines;
    for my $i (0..$num_columns-1) {
        my $text_lines = [];
        my $linum = 0;
        for my $line (split /^/m, $texts->[$i]) {
            $linum++;
            chomp $line;
            if ($on_long_line eq 'wrap') {
                push @$text_lines, (map {[$linum, $_]} split /\R/, Text::ANSI::WideUtil::ta_mbwrap($line, $column_width));
            } elsif ($on_long_line eq 'keep') { # for testing
                push @$text_lines, [$linum, $line];
            } else { # clip
                push @$text_lines, [$linum, Text::ANSI::WideUtil::ta_mbpad($line, $column_width, "right", " ", "truncate")];
            }
        }
        $text_lines[$i] = $text_lines;
    }

    my $linum = 0;
    while (1) {
        my @column_text;
        my $a_column_has_output;
        $linum++;
        for my $i (0..$num_columns-1) {
            if ($linum > @{ $text_lines[$i] }) {
                push @column_text, " " x $column_width;
                next;
            }
            push @column_text, $text_lines[$i][$linum-1][1];
            $a_column_has_output++;
        }
        last unless $a_column_has_output;
        if ($show_linum) {
            my $max_linum_display = 10**$linum_width - 1;
            print ($linum > $max_linum_display ? substr($max_linum_display, 0, $linum_width-1)."*" : sprintf($linum_fmt, $linum));
            print $separator;
        }
        print join($separator, @column_text);
        print "\n";
    }

    [200];
}

1;
#ABSTRACT:
