no strict 'vars';
$self->{CCFLAGS} = $Config{ccflags} . ' -DNO_LOCALECONV_GROUPING -DNO_LOCALECONV_MON_GROUPING';

