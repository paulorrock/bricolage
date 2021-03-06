#!/usr/bin/perl -w

use strict;
use File::Spec::Functions qw(catdir updir);
use FindBin;
use lib catdir $FindBin::Bin, updir, 'lib';
use bric_upgrade qw(:all);
use Bric::Util::DBI qw(:all);

exit if test_table 'story__output_channel';

do_sql
  # Create story__output_channel.
  q{CREATE TABLE story__output_channel (
      story_instance__id  NUMERIC(10, 0)  NOT NULL,
      output_channel__id  NUMERIC(10, 0)  NOT NULL,
      CONSTRAINT pk_story_output_channel
        PRIMARY KEY (story_instance__id, output_channel__id))},

  # Create media__output_channel.
  q{CREATE TABLE media__output_channel (
      media_instance__id  NUMERIC(10, 0)  NOT NULL,
      output_channel__id  NUMERIC(10, 0)  NOT NULL,
      CONSTRAINT pk_media_output_channel
        PRIMARY KEY (media_instance__id, output_channel__id))},
  ;


# Now add data to these tables based on existing records in the database.
for my $asset (qw(story media)) {

    # Query to get asset instance IDs and their corresponding element IDs.
    my $asset_sel = prepare(qq{
        SELECT i.id, a.element__id
        FROM   $asset a, ${asset}_instance i
        WHERE  a.id = i.${asset}__id
    });

    # Query to get output channel IDs for a given element ID.
    my $oc_sel = prepare(qq{
        SELECT output_channel__id
        FROM   element__output_channel
        WHERE  element__id = ?
               AND active = 1
    });

    # Inserts data into new asset to output channel mapping table.
    my $ins = prepare(qq{
        INSERT INTO ${asset}__output_channel
               (${asset}_instance__id, output_channel__id)
        VALUES (?, ?)
    });

    my ($aid, $eid, %ocs);
    execute($asset_sel);
    bind_columns($asset_sel, \$aid, \$eid);
    while (fetch($asset_sel)) {
        # Get a list of output channels for a given element ID.
        $ocs{$eid} ||= col_aref($oc_sel, $eid);
        for my $ocid (@{ $ocs{$eid} }) {
            # Associate existing story instances with each output channel ID
            # for the current element.
            execute($ins, $aid, $ocid);
        }
    }

}

__END__
