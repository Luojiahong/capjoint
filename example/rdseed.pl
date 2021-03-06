#!/usr/bin/env perl
use strict;
use warnings;
$ENV{SAC_DISPLAY_COPYRIGHT} = 0;

@ARGV == 1 or die "Usage: perl $0 dir\n";
my ($dir) = @ARGV;

chdir $dir;

# 删除之前可能存在的SAC文件和RESP文件
unlink glob "*.SAC";
unlink glob "RESP*";
unlink glob "*.[rtz]";
unlink "rdseed.err_log";

# 解压seed文件
foreach my $seed (glob "*.seed *.SEED") {
    system "rdseed -Rdf $seed";
}

# 合并数据

# 利用hash的key的不可重复性构建集合:
#   hash的key定义为 NET.STA.LOC.CHN
#   hash的value是文件名与key匹配的SAC文件数目
my %sets;
foreach (glob "*.SAC") {
    # 将文件名用'.'分割，并取其中的第7到10个元素
    my ($net, $sta, $loc, $chn) = (split /\./)[6..9];
    $sets{"$net.$sta.$loc.$chn"}++;
}

open(SAC, "|sac") or die "Error in opening sac\n";
print SAC "wild echo off \n";
my @to_del;
while (my ($key, $value) = each %sets) {
    # 检查每个key所对应的value，只有value大于1时才需要merge
    next if $value == 1;

    print STDERR "merge $key: $value traces\n";
    my @traces = sort glob "*.$key.?.SAC";
    # 对glob的返回值做sort，以保证第一个元素是最早的数据段

    # 在SAC中使用通配符而不是使用@traces以避免命令行过长的问题
    # merge不支持通配符
    print SAC "r *.$key.?.SAC \n";  # SAC v101.6 or later only
    print SAC "merge \n";
    print SAC "w $traces[0] \n";  # 以最早数据段的文件名保存

    # 将要删除的数据段文件名保存到数组中，待退出SAC后再删除
    push @to_del, splice(@traces, 1);
}
print SAC "q\n";
close(SAC);
unlink(@to_del);

# 文件重命名
foreach my $file (glob "*.SAC") {
    my ($year, $jday, $hour, $min, $sec, $msec,
    $net, $sta, $loc, $chn, $q, $suffix) = split /\./, $file;
    rename $file, "$net.$sta.$loc.$chn.SAC";
}

chdir "..";
