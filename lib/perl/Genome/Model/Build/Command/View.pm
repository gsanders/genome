package Genome::Model::Build::Command::View;

use strict;
use warnings;

use Genome;
use Genome::Utility::Text 'justify';

use DateTime::Format::Strptime;
use Date::Calc "Delta_DHMS";

our $ID_LENGTH = 32;

our %STATUS_COLORS = (
    new => "white",
    scheduled => "white",

    running => "cyan",

    done => "green",
    succeeded => "green",

    abandoned => "magenta",

    crashed => "red",
    failed => "red",
    unstartable => "red",
);

our %WORKFLOW_NAME_COLORS = (
    "inputconnector" => "white",
    "outputconnector" => "white",
);

our %CONNECTOR_NAMES = (
    "inputconnector" => 1,
    "outputconnector" => 1,
);

class Genome::Model::Build::Command::View {
    is => 'Genome::Command::Viewer',
    has => [
        build => {
            is => 'Genome::Model::Build',
            shell_args_position => 1,
            doc => 'Genome::Model::Build',
        },
        connectors => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Display input/output connectors in workflow.'
        },
        depth => {
            is => 'Int',
            is_optional => 1,
            default_value => -1,
            doc => 'Maximum workflow child depth.  Negative means infinite.'
        },
        events => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Display build events.'
        },
        notes => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Display build notes.'
        },
        full => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Display all build information. Equivalent to "--events --inputs --workflow --notes".'
        },
        inputs => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Display build inputs.'
        },
        workflow => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 1,
            doc => 'Display workflow.',
        },
    ],
};

sub help_synopsis {
    my $self = shift;
    my $result .= <<EOP;
    Displays basic information about a build.
EOP
    return $result;
}

sub help_detail {
    my $self = shift;
    my $result .= <<EOP;
Displays information about the events, inputs, and workflow for a build.

To display a full report about a build try:

    genome model build view --full <build_id>

This will display almost all the information about the build, excluding input and output connectors.
To also include input and ouput connectors:

    genome model build view --full --connectors <build_id>
EOP
    return $result;
}

sub write_report {
    my ($self, $width, $handle) = @_;

    my $build = $self->build;
    $self->_display_build($handle, $build);

    for my $thing (["inputs", "Inputs", "_display_input"],
                   ["events", "Events", "_display_event"],
                   ["notes", "Notes", "_display_note"]) {
        my ($item, $section_name, $method_name) = @{$thing};
        if($self->full || $self->$item) {
            my @items = $build->$item;
            $self->_display_many($handle, $section_name,
                    $method_name, @items);
        }
    }

    if ($self->full || $self->workflow) {
        my $workflow = $self->build->newest_workflow_instance;
        $self->_display_workflow($handle, $workflow);
    }

    1;
}

sub _display_build {
    my ($self, $handle, $build) = @_;

    my $processing_profile = $build->model->processing_profile;

    my $format_str = <<EOS;
%s
%s %s
%s %s
%s %s
%s       %s

%s
%s

EOS

    print $handle sprintf($format_str,
        $self->_color_heading('Build'),
        $self->_color_pair('Build ID',
            $self->_pad_right($build->id, $ID_LENGTH)),
        $self->_color_pair('Build Status',
            $self->_status_color($build->status)),
        $self->_color_pair('Model ID',
            $self->_pad_right($build->model->id, $ID_LENGTH)),
        $self->_color_pair('Model Name', $build->model->name),
        $self->_color_pair('Run by', $self->_pad_right($build->run_by, 34)),
        $self->_color_pair('Processing Profile ID', $processing_profile->id),
        $self->_color_pair('Build Scheduled',
            $self->_clean_up_timestamp($build->date_scheduled)),
        $self->_color_pair('Build Completed',
            $self->_clean_up_timestamp($build->date_completed)),
        $self->_color_pair('Software Revision', $build->software_revision),
        $self->_color_pair('Data Directory', $build->data_directory));
}

sub _display_many {
    my ($self, $handle, $section_name, $method_name, @items) = @_;

    print $handle $self->_color_heading($section_name) . "\n";
    if(@items) {
        for my $item (@items) {
            $self->$method_name($handle, $item);
        }
    } else {
        print $handle "None\n";
    }
    print $handle "\n";
}

sub _display_note {
    my ($self, $handle, $note) = @_;

    print $handle $self->_color_pair("Editor", $note->editor_id);
    print $handle $self->_color_pair("    Date/Time", $note->entry_date) . "\n";
    print $handle $self->_color_pair("    Header", $note->header_text) . "\n";
    print $handle $self->_color_pair("    Body", $note->body_text) . "\n";
}

sub _display_input {
    my ($self, $handle, $input) = @_;

    print $handle $input->name . "\n";
    print $handle $self->_color_pair('    ID', $input->value_id) . "\n";
    print $handle $self->_color_pair('    Type', $input->value_class_name) . "\n";
}

sub _display_event {
    my ($self, $handle, $event) = @_;

    my $format_str = <<EOS;
%s %s
    %s
    %s   %s
    %s
EOS
    print $handle sprintf($format_str,
        $self->_color_pair('ID', $self->_pad_right($event->id, $ID_LENGTH)),
        $self->_color_pair('Status',
            $self->_status_color($event->event_status)),
        $self->_color_pair('Name', $event->event_type),
        $self->_color_pair('Scheduled',
            $self->_clean_up_timestamp($event->date_scheduled)),
        $self->_color_pair('Completed',
            $self->_clean_up_timestamp($event->date_completed)),
        $self->_color_pair('LSF ID', $event->lsf_job_id));
}

sub _display_workflow {
    my ($self, $handle, $workflow) = @_;

    unless ($self->_display_workflow_header($handle, $workflow)) {
        return 0;
    }

    # datetime_parser only needed for calculating the elapsed time.
    my $datetime_parser = DateTime::Format::Strptime->new(
            pattern => '%Y-%m-%d %H:%M:%S',
            on_error => 'croak');
    my $failed_workflow_steps = [];
    $self->_display_workflow_children($handle, $workflow, $datetime_parser,
            $failed_workflow_steps);

    my @error_log_paths;
    my @step_names;
    for my $failed_step (@{$failed_workflow_steps}) {
        if($failed_step->current->can('stderr')) {
            my $error_path = $failed_step->current->stderr || ' ';
            if(-e $error_path) {
                push(@error_log_paths, $error_path);
                push(@step_names, $failed_step->name);
            }
        }
    }
    if(@error_log_paths) {
        printf $handle "\n%s\n", $self->_color('Error Logs:', 'bold');
        for my $i (0..$#error_log_paths) {
            my $name = $step_names[$i];
            my $length = 22;
            if(length($name) > $length) {
                $name = substr($name, 0, $length-3) . "...";
            }
            my $log_path = $error_log_paths[$i];
            printf $handle "%s %s\n", justify($name, 'left', $length),
                    $log_path;
        }
    }
}

sub _display_workflow_header {
    my ($self, $handle, $workflow) = @_;

    unless ($workflow) {
        return 0;
    }

    # workflow->current is the InstanceExecution
    my $ie = $workflow->current;

    my $format_str = <<EOS;
%s
%s %s
%s         %s
%s               %s

EOS
    print $handle sprintf($format_str,
        $self->_color_heading('Workflow'),
        $self->_color_pair('ID', $self->_pad_right($workflow->id, $ID_LENGTH)),
        $self->_color_pair('Name', $workflow->name),
        $self->_color_pair('Started',
            $self->_clean_up_timestamp($ie->start_time)),
        $self->_color_pair('Ended', $self->_clean_up_timestamp($ie->end_time)),
        $self->_color_pair('User', $self->_pad_right($ie->user_name, 16)),
        $self->_color_pair('Cache ID', $workflow->cache_workflow_id));
}

sub _display_workflow_children {
    my ($self, $handle, $workflow, $datetime_parser,
        $failed_workflow_steps) = @_;

    print $handle $self->_color_dim($self->_format_workflow_child_line(
            "ID", "Status", "LSF ID", "Start Time", "Time Elapsed", "Name"));

    $self->_display_workflow_child($handle, $workflow, $datetime_parser, 0,
            $failed_workflow_steps);

    1;
}

sub _display_workflow_child {
    my ($self, $handle, $child, $datetime_parser, $nesting_level,
            $failed_workflow_steps) = @_;

    my $status = $child->status;

    my ($start_time, $elapsed_time) = $self->_resolve_child_times(
        $child->start_time, $child->end_time, $status, $datetime_parser);

    if ($self->connectors || !$self->_is_connector($child->name)) {
        if($status eq 'failed' or $status eq 'crashed') {
            push(@{$failed_workflow_steps}, $child);
        }
        print $handle $self->_format_workflow_child_line($child->id, $status,
            $child->current->dispatch_identifier, $start_time, $elapsed_time,
            ('  'x$nesting_level) . $child->name);
    }

    if ($self->depth < 0 || $nesting_level < $self->depth) {
        if ($child->can('related_instances')) {
            for my $subchild ($child->related_instances) {
                $self->_display_workflow_child($handle, $subchild,
                        $datetime_parser, $nesting_level + 1,
                        $failed_workflow_steps);
            }
        }
    }

    1;
}

# -- additional helper functions --
sub _is_connector {
    my ($self, $workflow_name) = @_;

    my $stripped_workflow_name = $self->_strip_key($workflow_name);

    return exists $CONNECTOR_NAMES{$stripped_workflow_name};
}

sub _build_is_abandoned {
    my ($self, $build) = @_;

    return 'Abandoned' eq $build->status;
}

# Returns formatted strings for start time and elapsed time.
sub _resolve_child_times {
    my ($self, $raw_start_time, $raw_end_time, $status, $datetime_parser) = @_;

    unless ($raw_start_time) {
        return ('', '');
    }

    my $start_time = $self->_clean_up_timestamp($raw_start_time);
    my $start_datetime = $datetime_parser->parse_datetime($start_time);

    unless ($start_datetime) {
        return ('', '');
    }

    my $end_datetime;
    if ($raw_end_time) {
        $end_datetime = $datetime_parser->parse_datetime(
            $self->_clean_up_timestamp($raw_end_time));
    } elsif ("running" eq $self->_strip_key($status)) {
        $end_datetime = $self->_resolve_running_child_end_time();
    } else {
        return ('', '');
    }

    if (defined $end_datetime) {
        my $elapsed_time = $self->_resolve_duration(
            $start_datetime, $end_datetime);
        return $start_time, $elapsed_time;
    }
    return $start_time, '';
}

sub _resolve_running_child_end_time {
    my ($self) = @_;
    unless ('Abandoned' eq $self->build->status) {
        return DateTime->now(time_zone=>'local');
    }
    return;
}

sub _format_workflow_child_line {
    my ($self, $id, $status, $dispatch_id, $start_time, $elapsed_time, $name) = @_;
    $dispatch_id = $self->_format_dispatch_id($dispatch_id);
    return sprintf("%s %s %s %s %s  %s\n",
        $self->_pad_right($id, 9),
        $self->_status_color($self->_pad_right($status, 9)),
        $dispatch_id,
        $self->_pad_right($start_time, 19),
        $self->_workflow_elapsed_color(
            $self->_pad_left($elapsed_time, 13), $name, $dispatch_id),
        $self->_workflow_name_color($name));
}

sub _format_dispatch_id {
    my ($self, $dispatch_id) = @_;
    $dispatch_id = ' ' unless defined($dispatch_id);
    $dispatch_id =~ s/^P\d+/shortcut/;

    $dispatch_id = $self->_pad_right($dispatch_id, 10);
    if($dispatch_id =~ /shortcut/) {
        $dispatch_id = $self->_color($dispatch_id, 'white');
    }
    return $dispatch_id
}

sub _status_color {
    my ($self, $text) = @_;
    return $self->_colorize_text_by_map($text, $text, %STATUS_COLORS);
}

sub _workflow_name_color {
    my ($self, $text) = @_;
    return $self->_colorize_text_by_map($text, $text, %WORKFLOW_NAME_COLORS);
}

sub _workflow_elapsed_color {
    my ($self, $text, $workflow_name, $dispatch_id) = @_;
    if($dispatch_id =~ /shortcut/) {
        return $self->_color($text, 'white');
    } else {
        return $self->_colorize_text_by_map($text, $workflow_name,
            %WORKFLOW_NAME_COLORS);
    }
}

sub _colorize_text_by_map {
    my ($self, $text, $color_key, %color_map) = @_;

    my $stripped_key = $self->_strip_key($color_key);
    if (exists $color_map{$stripped_key}) {
        return $self->_color($text, $color_map{$stripped_key});
    }

    return $text;
}

sub _strip_key {
    my ($self, $text) = @_;

    my $stripped_text = $text;
    $stripped_text =~ tr/A-Z/a-z/;
    $stripped_text =~ s/ //g;

    return $stripped_text;
}

sub _color_heading {
    my ($self, $text) = @_;
    return $self->_color_dim('=== ') . $self->_color($text, 'bold') .
        $self->_color_dim(' ===');
}

sub _color_pair {
    my ($self, $key, $value) = @_;
    return $self->_color_dim($key.':') . ' ' . ($value || '');
}

sub _color_dim {
    my ($self, $text) = @_;
    return $self->_color($text, 'white');
}

sub _resolve_duration {
    my ($self, $d1, $d2) = @_;

    my ($days, $hours, $minutes, $seconds) = Delta_DHMS(
        $d1->year, $d1->month, $d1->day, $d1->hour, $d1->minute, $d1->second,
        $d2->year, $d2->month, $d2->day, $d2->hour, $d2->minute, $d2->second);

    my $day_string   = $self->_pad_left($days   ? $days."d":"", 4);

    return sprintf("$day_string %02d:%02d:%02d", $hours, $minutes, $seconds);
}

sub _pad_left {
    my ($self, $arg, $length) = @_;
    return justify($arg, 'right', $length);

}

sub _pad_right {
    my ($self, $arg, $length) = @_;
    return justify($arg, 'left', $length);
}

sub _clean_up_timestamp {
    my ($self, $dirty_stamp) = @_;

    unless (defined $dirty_stamp) {
        return '';
    }

    my ($clean_stamp) = split('\.', $dirty_stamp);
    $clean_stamp =~ s/\s$//;
    return $clean_stamp;
}


1;
