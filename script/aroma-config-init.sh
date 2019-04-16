#!/sbin/sh

workPath=/magisk
settings_save_prop=/sdcard/TWRP/mmrt.prop

file_getprop() { grep "^$2=" "$1" | head -n1 | cut -d= -f2; }

ls_mount_path() { ls -1 ${workPath} | grep -v 'lost+found'; }

ls_modules_sort_by_id() { ls_mount_path | sort -f; }

ls_modules_sort_by_name() {
    local installed_modules_tmp=`ls_mount_path`
    [ ${#installed_modules_tmp} -eq 0 ] && return
    local idn_file=/tmp/mmr/modules_idm
    : > $idn_file
    for d in $installed_modules_tmp; do
        echo "$d, "$(file_getprop ${workPath}/${d}/module.prop name) >> $idn_file
    done
    sort -k2 -f $idn_file | while read line; do
        echo ${line%,*}
    done
}

gen_aroma_config() {
    if [ -f $settings_save_prop ] && [ $(file_getprop $settings_save_prop "sort_by_name") -eq 1 ]; then
        installed_modules=`ls_modules_sort_by_name`
    else
        installed_modules=`ls_modules_sort_by_id`
    fi
    ac_tmp=/tmp/mmr/script/aroma-config
    mv /tmp/mmr/script/ac-1.in $ac_tmp
    if [ ${#installed_modules} -eq 0 ]; then
        echo "    \"如果你看到了此选项\", \"说明你尚未安装任何 Magisk 模块...\", \"@what\"," >> $ac_tmp
    else
        for module in ${installed_modules}; do
            echo "    file_getprop(\"${workPath}/${module}/module.prop\", \"name\") || \"(未提供信息)\"," >> $ac_tmp
            echo "    \"<i><b>\" + (file_getprop(\"${workPath}/${module}/module.prop\", \"version\") || \"(未提供信息)\") +" >> $ac_tmp
            echo "    \"\n作者: \" + (file_getprop(\"${workPath}/${module}/module.prop\", \"author\") || \"(未提供信息)\") + \"</b></i>\"," >> $ac_tmp
            echo "    prop(\"module_icon.prop\", \"module.icon.${module}\") || \"@removed\"," >> $ac_tmp
        done
    fi
    cat >> $ac_tmp <<EOF
    "高级选项", "", "@action"
);

# Reboot
if prop("operations.prop", "selected") == "1" then
    if confirm("重启",
               "您确定要重启设备吗?",
               "@warning") == "yes"
    then
        exec("/sbin/sh", "/tmp/mmr/script/done-script.sh");
        reboot("now");
    endif;
endif;

# Exit
if prop("operations.prop", "selected") == "2" then
    if confirm("退出",
               "您确定要退出 Magisk Manager Recovery 工具吗?",
               "@warning") == "yes"
    then
        exec("/sbin/sh", "/tmp/mmr/script/done-script.sh");
        exit("");
    endif;
endif;

EOF
    if [ ${#installed_modules} -eq 0 ]; then
        i=3
    else
        i=2
        for module in ${installed_modules}; do
            let i+=1
            echo "if prop(\"operations.prop\", \"selected\") == \"$i\" then" >> $ac_tmp
            echo "    setvar(\"modid\", \"$module\");" >> $ac_tmp
            echo "    setvar(\"modname\", file_getprop(\"${workPath}/${module}/module.prop\", \"name\") || \"(未提供信息)\");" >> $ac_tmp
            echo "    setvar(\"modsize\", \"$(du -sh ${workPath}/${module} | awk '{print $1}')\");" >> $ac_tmp
            echo "endif;" >> $ac_tmp
            echo "" >> $ac_tmp
        done
    fi
    cat >> $ac_tmp <<EOF
if cmp(prop("operations.prop", "selected"), ">=", "3") &&
   cmp(prop("operations.prop", "selected"), "<=", "$i") &&
   getvar("modid") != ""
then

    setvar("stat_code", exec("/sbin/sh", "/tmp/mmr/script/control-module.sh", "status", getvar("modid")));
    setvar("stat_mount_code", exec("/sbin/sh", "/tmp/mmr/script/control-module.sh", "status_" + getvar("mount_switch_flag") + "_mount", getvar("modid")));

    if getvar("stat_code") == "2" then
        alert(
            "注意",
            "这个模块已经被移除了.\n",
            "@warning",
            "确定"
        );
        back("1");
    endif;

    if getvar("stat_code") == "0" || getvar("stat_code") == "5" then
        setvar("module_status", "已禁用");
        setvar("module_status_switch_text",  "启用该模块");
        setvar("module_status_switch_text2", "");
        setvar("module_status_switch_icon",  "@action2");
    endif;
    if getvar("stat_code") == "1" || getvar("stat_code") == "4" then
        setvar("module_status", "已启用");
        setvar("module_status_switch_text",  "禁用该模块");
        setvar("module_status_switch_text2", "");
        setvar("module_status_switch_icon",  "@offaction");
    endif;
    if cmp(getvar("stat_code"), ">=", "4") then
        setvar("module_status", "待移除");
        setvar("module_remove_switch_text",  "<b><i>撤销</i></b> 重启后移除该模块");
        setvar("module_remove_switch_text2", "");
        setvar("module_remove_switch_icon",  "@refresh");
    else
        setvar("module_remove_switch_text",  "重启后移除该模块");
        setvar("module_remove_switch_text2", "");
        setvar("module_remove_switch_icon",  "@delete");
    endif;

    if getvar("stat_mount_code") == "0" then
        setvar("module_mount_status", "已禁用");
        setvar("module_mount_status_switch_text",  "启用挂载");
        setvar("module_mount_status_switch_text2", "");
        setvar("module_mount_status_switch_icon",  "@action2");
    endif;
    if getvar("stat_mount_code") == "1" then
        setvar("module_mount_status", "已启用");
        setvar("module_mount_status_switch_text",  "禁用挂载");
        setvar("module_mount_status_switch_text2", "");
        setvar("module_mount_status_switch_icon",  "@offaction");
    endif;

    if getvar("stat_code") == "3" then
        setvar("module_status", "待更新");
        setvar("module_status_switch_text",        "启用/禁用该模块");
        setvar("module_status_switch_text2",       "不允许的操作");
        setvar("module_status_switch_icon",        "@crash");
        setvar("module_mount_status_switch_text",  "启用/禁用挂载");
        setvar("module_mount_status_switch_text2", "不允许的操作");
        setvar("module_mount_status_switch_icon",  "@crash");
        setvar("module_remove_switch_text2",       "不允许的操作");
        setvar("module_remove_switch_icon",        "@crash");
        setvar("module_remove_text2",              "不允许的操作");
        setvar("module_remove_icon",               "@crash");
    endif;

    menubox(
        "模块: " + getvar("modname"),
        "模块 ID: " + getvar("modid") + "\n" +
        "占用空间: " + getvar("modsize") + "\n" +
        "模块状态: " + getvar("module_status") + "\n" +
        "挂载状态: " + getvar("module_mount_status"),
        "@welcome",
        "modoperations.prop",

        "查看模块描述", "", "@info",
        "预览模块内容", "", "@info",
        getvar("module_status_switch_text"), getvar("module_status_switch_text2"), getvar("module_status_switch_icon"),
        getvar("module_mount_status_switch_text"), getvar("module_mount_status_switch_text2"), getvar("module_mount_status_switch_icon"),
        getvar("module_remove_switch_text"), getvar("module_remove_switch_text2"), getvar("module_remove_switch_icon"),
        getvar("module_remove_text"), getvar("module_remove_text2"), getvar("module_remove_icon")
    );

    if prop("modoperations.prop", "selected") == "1" then
        alert(
            "描述",
            file_getprop("${workPath}/" + getvar("modid") + "/module.prop", "description") || "(未提供信息)",
            "@info",
            "返回"
        );
        back("1");
    endif;
    if prop("modoperations.prop", "selected") == "2" then
        exec("/sbin/sh", "/tmp/mmr/script/get-module-tree.sh", getvar("modid"));
        textbox(
            "预览",
            "模块目录结构:",
            "@info",
            getvar("exec_buffer")
        );
        back("2");
    endif;
    if getvar("stat_code") == "3" then
        alert(
            "不允许的操作",
            "该模块将在重启后完成更新,\n请重启一次后再试.",
            "@crash",
            "返回"
        );
        back("1");
    endif;
    prop("modoperations.prop", "selected") == "3" && setvar("module_operate", "switch_module");
    prop("modoperations.prop", "selected") == "4" && setvar("module_operate", "switch_" + getvar("mount_switch_flag") + "_mount");
    prop("modoperations.prop", "selected") == "5" && setvar("module_operate", "switch_remove");
    if prop("modoperations.prop", "selected") == "6" then
        if confirm("警告",
                   "您确定要移除该模块吗? 此操作不可恢复!",
                   "@warning") == "yes"
        then
            setvar("module_operate", "remove");
        else
            back("1");
        endif;
    endif;
    if exec("/sbin/sh", "/tmp/mmr/script/control-module.sh", getvar("module_operate"), getvar("modid")) == "0" then
        alert(
            "成功",
            getvar("exec_buffer"),
            "@done",
            "确定"
        );
    else
        alert(
            "失败",
            getvar("exec_buffer"),
            "@crash",
            "确定"
        );
    endif;
    prop("modoperations.prop", "selected") != "6" && back("1");
endif;

if prop("operations.prop", "selected") == cal("$i", "+", "1") then
    menubox(
        "高级功能",
        "请选择操作" + getvar("core_only_mode_warning"),
        "@welcome",
        "advanced.prop",

        "保存 recovery 日志", "复制 /tmp/recovery.log 到内部存储", "@action",
        "瘦身 magisk.img", getvar("shrink_text2"), getvar("shrink_icon"),
        getvar("core_only_mode_switch_text"), getvar("core_only_mode_switch_text2"), "@action",
        "清除 MagiskSU 日志", "", "@action",
        "移除所有 MagiskSU 授权", "移除所有已保存的应用 MagiskSU 授权", "@action",
        "拒绝所有 MagiskSU 授权", "拒绝所有已保存的应用 MagiskSU 授权", "@action",
        "允许所有 MagiskSU 授权", "允许所有已保存的应用 MagiskSU 授权", "@action",
        "选择模块列表排序方式", "当前: " + getvar("sort_text2"), "@action",
        "返回", "", "@back2"
    );
    if prop("advanced.prop", "selected") == "1" then
        exec("/sbin/sh", "/tmp/mmr/script/save-rec-log.sh");
        alert(
            "完成",
            "已保存 Recovery 日志到 /sdcard/recovery.log!",
            "@done",
            "确定"
        );
        back("1");
    endif;
    if prop("advanced.prop", "selected") == "2" then
        if cmp(getvar("MAGISK_VER_CODE"), ">", "18100") then
            back("1");
        else
            pleasewait("正在执行脚本 ...");
            if exec("/sbin/sh", "/tmp/mmr/script/shrink-magiskimg.sh") == "0" then
                alert(
                    "运行成功",
                    getvar("exec_buffer"),
                    "@done",
                    "确定"
                );
                if confirm(
                    "注意",
                    "magisk 镜像已取消挂载.\n\n本工具即将退出.\n如果还需使用, 请重新卡刷本工具.\n\n",
                    "@warning",
                    "退出到 Recovery",
                    "重启设备") == "no"
                then
                    reboot("now");
                endif;
            else
                alert(
                    "运行失败",
                    getvar("exec_buffer"),
                    "@crash",
                    "退出"
                );
            endif;
            exit("");
        endif;
    endif;
    if prop("advanced.prop", "selected") == "3" then
        exec("/sbin/sh", "/tmp/mmr/script/core-mode.sh", "switch");
        alert(
            "完成",
            getvar("exec_buffer"),
            "@done",
            "确定"
        );
        back("1");
    endif;
    prop("advanced.prop", "selected") == "4" && setvar("sqlite_operate", "clear_su_log");
    prop("advanced.prop", "selected") == "5" && setvar("sqlite_operate", "clear_su_policies");
    prop("advanced.prop", "selected") == "6" && setvar("sqlite_operate", "reject_all_su");
    prop("advanced.prop", "selected") == "7" && setvar("sqlite_operate", "allow_all_su");
    if cmp(prop("advanced.prop", "selected"), ">=", "4") &&
       cmp(prop("advanced.prop", "selected"), "<=", "7")
    then
        if prop("advanced.prop", "selected") == "5" then
            if confirm("警告",
                       "您确定要移除所有 MagiskSU 授权吗?\n此操作不可恢复!",
                       "@warning") == "no"
            then
                back("1");
            endif;
        endif;
        pleasewait("正在执行脚本 ...");
        if exec("/sbin/sh", "/tmp/mmr/script/control-sqlite.sh", getvar("sqlite_operate")) == "0" then
            alert(
                "成功",
                "操作完成, 执行过程中没有发生错误.",
                "@done",
                "确定"
            );
            back("1");
        else
            alert(
                "失败",
                "执行过程中有错误发生, 请确认.\n\n" + getvar("exec_buffer"),
                "@crash",
                "确定"
            );
            back("1");
        endif;
    endif;
    if prop("advanced.prop", "selected") == "8" then
        if confirm(
            "选择模块列表排序方式",
            "请选择排序依据:",
            "@info",
            getvar("sort_text2_s1"),
            getvar("sort_text2_s2")) == "yes"
        then
            setvar("sort_by_name", "0");
        else
            setvar("sort_by_name", "1");
        endif;
        exec("/sbin/sh", "/tmp/mmr/script/save-settings.sh", "sort_by_name", getvar("sort_by_name"));
        alert(
            "完成",
            "已设置为" + iif(getvar("sort_by_name") == "0", getvar("sort_text2_s1"), getvar("sort_text2_s2")) +
            ",\n将在下次使用本工具时生效.",
            "@done",
            "确定"
        );
        back("1");
    endif;
endif;

goto("main_menu");
EOF
    sync
}

gen_aroma_config
