#############################################################################
# Copyright (C) 2022 Thales DIS France SAS
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0.
#
# Original Author: Zbigniew Chamski (zbigniew.chamski@thalesgroup.com)
#############################################################################
## Config is Project dependent. It is imported from platform_package

"""
Manipulate and render basic objects composing the Verification Plan:
- features
- sub-features
- verification items
"""

import sys
import os
from datetime import datetime
import re

# Load the configuration associated with the current platform
if "PLATFORM_TOP_DIR" in os.environ:
    lib_path = os.path.abspath(os.path.join(os.environ["PLATFORM_TOP_DIR"], "vptool"))
    sys.path.append(lib_path)
    try:
        import vp_config

        vp_config.io_fmt_gitrev = "$Id$"
    except ImportError as e:
        print("ERROR: Please define path to vp_config package (got " + str(e) + "!)")
        sys.exit(1)
else:
    print("ERROR: Environment variable 'PLATFORM_TOP_DIR' not set, cannot continue!")
    sys.exit(1)


def remove_non_ascii(text):
    """Remove non-ASCII characters from a string."""
    return "".join([x for x in text if ord(x) < 128])


def normalize_tag(tag):
    """
    Normalize a heritage VP_IPnnn_Pnnn_Innn tag
    to VP_<PROJECT_IDENT>_Fnnn_Snnn_Innn form.
    """
    pattern_oldstyle = re.compile(r"VP_IP([0-9]+)_P([0-9]+)_I([0-9]+)$")
    match = pattern_oldstyle.match(tag)
    if match and match.group() == tag:
        # Full match
        return "VP_" + vp_config.PROJECT_IDENT + "_F%s_S%s_I%s" % match.groups()

    # Partial match or no match at all: return unmodified label.
    return tag


def yaml_default(field):
    """Return default value associated with GUI field FIELD in Yaml config."""
    return vp_config.yaml_config["gui"][field]["default"]["value"]


#####################################
##### Class Definition
class Item:
    """
    An item defines a specific case to test depending on its parent property
    It is intended to be instantiated in Prop class
    """

    count = 0
    attr_names = ["description", "purpose", "verif_goals", "coverage_loc", "comments"]
    gui_fields = [
        "feature_descr",
        "requirement_loc",
        "verif_goals",
        "coverage_loc",
        "comments",
    ]

    def __init__(self, item_ref_name=0, tag="", description="", purpose=""):
        self.name = str(item_ref_name)
        self.tag = tag
        # Description of feature to be tested
        self.description = description
        # Requirement to be verified
        self.purpose = purpose
        # Summary of verification goals
        self.verif_goals = ""
        # Location of coverage data
        self.coverage_loc = ""
        self.pfc = yaml_default("pfc")  # none selected, must choose
        self.test_type = yaml_default("test_type")  # none selected, must choose
        self.cov_method = yaml_default("cov_method")  # none selected, must choose
        self.cores = yaml_default("cores")  # applicable to all cores
        self.comments = ""
        self.status = ""
        self.simu_target_list = []
        self.__class__.count += 1
        self.rfu_list = []
        self.rfu_list_2 = []
        self.rfu_dict = {}  # used as lock. will be updated with class update
        self.rfu_dict["lock_status"] = 0

    def attrval2str(self, attr):
        """Convert numerical attribute value to human-readable form."""
        if attr == "cores" and "cores" in vp_config.yaml_config:
            # 'cores' are at toplevel of the Yaml config and the attr value is a bitmap.
            # Select entries corresponding to each bit that is set
            # and return a comma-separated list of associated names.
            matches = [
                x["label"]
                for x in vp_config.yaml_config[attr]["values"]
                if x["value"] & getattr(self, attr) != 0
            ]
            if len(matches) == 0:
                return "None applicable"
            return ", ".join(matches)
        if "values" in vp_config.yaml_config["gui"][attr]:
            # This attribute takes predefined values.
            # A single value is allowed.
            if (
                getattr(self, attr)
                == vp_config.yaml_config["gui"][attr]["default"]["value"]
            ):
                return "NDY (Not Defined Yet)"
            matches = [
                x["label"]
                for x in vp_config.yaml_config["gui"][attr]["values"]
                if x["value"] == getattr(self, attr)
            ]
            if len(matches) == 0:
                return "<UNKNOWN>"
            return matches[0]
        return "N/A (unsupported field '%s')" % attr

    def preserve_linebrs(self, text, indent="  "):
        """
        Preserve line breaks in the text by inserting two spaces before
        each newline.  Ensure first line of 'text' starts on a new line.
        """
        md_linebreak = "  \n" + indent
        return md_linebreak + md_linebreak.join(text.split("\n"))

    def __str__(self):
        return0 = ""
        return0 += format("#### Item: %s\n\n" % self.name)
        return0 += format("* **Requirement location:** %s\n" % self.purpose)
        return0 += format(
            "* **Feature Description**\n%s\n" % self.preserve_linebrs(self.description)
        )
        return0 += format(
            "* **Verification Goals**\n%s\n" % self.preserve_linebrs(self.verif_goals)
        )
        return0 += format("* **Pass/Fail Criteria:** %s\n" % self.attrval2str("pfc"))
        return0 += format("* **Test Type:** %s\n" % self.attrval2str("test_type"))
        return0 += format(
            "* **Coverage Method:** %s\n" % self.attrval2str("cov_method")
        )
        return0 += format("* **Applicable Cores:** %s\n" % self.attrval2str("cores"))
        return0 += format(
            "* **Unique verification tag:** %s\n" % normalize_tag(self.tag)
        )
        if self.coverage_loc:
            return0 += format("* **Link to Coverage:** %s\n" % self.coverage_loc)
        if self.comments:
            return0 += format(
                "* **Comments**\n%s\n" % self.preserve_linebrs(self.comments)
            )
        return return0

    def __del__(self):
        self.__class__.count -= 1

    def invert_lock(self):
        """
        Invert lock status of the current item.
        If the lock is being set, store current timestamp and user ID inside
        the lock status entry of the state dict.
        """
        if self.is_locked():
            self.rfu_dict["lock_status"] = 0
        else:
            self.rfu_dict["lock_status"] = " ".join(
                (str(datetime.now()), os.getlogin())
            )

    def unlock(self):
        """Release the lock on the current item."""
        self.rfu_dict["lock_status"] = 0

    def lock(self):
        """
        Set the lock on the current item.  Store current timestamp and user ID inside
        the lock status entry of the state dict.
        """
        self.rfu_dict["lock_status"] = " ".join((str(datetime.now()), os.getlogin()))

    def is_locked(self):
        """Return True if the current item is locked."""
        return bool(self.rfu_dict["lock_status"])

    def get_lock_status(self):
        """Get the details of lock status of current item."""
        return str(self.rfu_dict["lock_status"])

    def prep_to_save(self):
        """
        Sanitize item before saving:
        - Remove default values of text fields
        - Normalize old-style (VP_IPnnn_Pnnn_Innn) tags to full form with
          project ident.
        """
        for (attr, field) in zip(Item.attr_names, Item.gui_fields):
            if getattr(self, attr) == vp_config.yaml_config["gui"][field]["cue_text"]:
                setattr(self, attr, "")
        self.tag = normalize_tag(self.tag)


class Prop:
    """
    A Property defines a specific behaviour or an IP section, to be tested/verified
    It is intended to be instantiated in Ip class.
    It contains a collection of Items.
    """

    def __init__(self, name="", tag="", wid_order=0):
        self.item_count = (
            0  # determine how many items have been created for a given property
        )
        self.name = name
        self.tag = tag
        self.item_list = {}
        self.wid_order = wid_order
        ## rfu for future dev
        self.rfu_list = []
        self.rfu_list_1 = []
        self.rfu_list_2 = []
        self.rfu_dict = {}

    def __str__(self):
        return format("### Sub-feature: %s\n\n" % (self.name))

    def prop_clone(self):
        """Clone an existing sub-feature."""
        new_prop = Prop()
        new_prop.item_count = self.item_count
        new_prop.name = self.name
        new_prop.tag = self.tag
        new_prop.item_list = self.item_list.copy()
        new_prop.wid_order = self.wid_order
        new_prop.rfu_list = self.rfu_list[:]
        new_prop.rfu_list_1 = self.rfu_list_1[:]
        new_prop.rfu_list_2 = self.rfu_list_2[:]
        new_prop.rfu_dict = self.rfu_dict.copy()
        return new_prop

    def add_item(self, tag, description="", purpose=""):
        """Add new item to current sub-feature."""
        new_item = Item(
            str(self.item_count).zfill(3),
            tag=tag + "_I" + str(self.item_count).zfill(3),
            description=description,
            purpose=purpose,
        )
        self.item_list[str(self.item_count).zfill(3)] = new_item
        self.item_count += 1
        # Return a ref to the newly created item.
        return new_item

    def del_item(self, index):
        """Remove an item at INDEX from current sub-feature."""
        del self.item_list[index]

    def get_item_name(self):
        """Get list of names of all items in current sub-feature."""
        item_name_list = []
        for item in self.item_list:
            item_name_list.append(item.name)
        return item_name_list

    def prep_to_save(self):
        """
        Trick used to ensure pickle output file stability
        Pickle doesn't provide reproductible output for dicts.
        When saved, they are converted to lists.
        """
        # Sanitize items of this Prop.
        for item in self.item_list.values():
            item.prep_to_save()
        self.rfu_list = sorted(list(self.item_list.items()), key=lambda key: key[0])
        self.item_list = {}

    def post_load(self):
        """
        Trick used to ensure pickle output file stability
        When loading saved db, list are converted back to initial dict
        """
        for item_key, item_elt in self.rfu_list:
            self.item_list[item_key] = item_elt
        self.rfu_list = []

    def insert_item(self, item_name):
        """
        This is intended to be used in specific cases as it
        can change every item numbering;
        Should not be used after item is implemented in simulations
        It inserts last item in self.item_list at insert index, and updates
        item tag and name accordingly
        """
        insert_index = int(item_name) + 1
        updated_dict = {}
        insert_index_string = str(insert_index).zfill(3)
        to_insert = self.item_list.pop(max(self.item_list.keys()))
        for elt in list(self.item_list.keys()):
            if int(elt) < insert_index:
                updated_dict[elt] = self.item_list[elt]
            else:
                updated_dict[str(int(elt) + 1).zfill(3)] = self.item_list[elt]
                updated_dict[str(int(elt) + 1).zfill(3)].tag = updated_dict[
                    str(int(elt) + 1).zfill(3)
                ].tag[:-3] + str(int(elt) + 1).zfill(3)
                updated_dict[str(int(elt) + 1).zfill(3)].name = str(int(elt) + 1).zfill(
                    3
                )
        updated_dict[insert_index_string] = to_insert
        updated_dict[insert_index_string].tag = (
            updated_dict[insert_index_string].tag[:-3] + insert_index_string
        )
        updated_dict[insert_index_string].name = insert_index_string
        self.item_list = updated_dict

    def unlock_items(self):
        """Unlock all items in current sub-feature."""
        for item in list(self.item_list.values()):
            item.unlock()

    def lock_items(self):
        """Lock all items in current sub-feature."""
        for item in list(self.item_list.values()):
            item.lock()


class Ip:
    """
    An IP defines a bloc instantiated at chip top level, or more generally,
    a design specification chapter that needs to be covered by a verification plan.
    It contains a collection of Prop.
    """

    _ip_count = 0

    def __init__(self, name="", index=""):
        self.prop_count = 0  # determine how many prop have been created for a given IP
        self.name = name
        self.prop_list = {}
        if index:
            self.ip_num = index  ## Store number creation
        else:
            self.ip_num = self.__class__._ip_count
        self.__class__._ip_count += 1
        self.wid_order = self.ip_num
        # rfu for future dev
        self.rfu_dict = {}
        self.rfu_list = []
        self.rfu_list_1 = []

    def __str__(self):
        return format("## Feature: %s\n\n" % (self.name))

    def add_property(self, name, custom_num=""):
        """Add a new sub-feature to current feature."""
        if name in list(self.prop_list.keys()):
            print("Property already exists")
            feedback = 0
        else:
            name = remove_non_ascii(name)
            prop_name = custom_num + str(self.prop_count).zfill(3) + "_" + str(name)
            self.prop_list[prop_name] = Prop(
                prop_name,
                tag="VP_"
                + vp_config.PROJECT_IDENT
                + "_F"
                + str(self.ip_num).zfill(3)
                + "_S"
                + str(self.prop_count).zfill(3),
                wid_order=self.prop_count,
            )
            feedback = self.prop_list[prop_name].tag
            self.prop_count += 1
        return (feedback, prop_name)

    def del_property(self, name):  #
        """Remove a sub-feature from current feature."""
        if (
            self.prop_count == int(self.prop_list[name].tag[-3:]) + 1
        ):  # with custom numbering max elt is not always the last one created
            self.prop_count -= 1
        del self.prop_list[str(name)]

    def clear(self):
        """Reset sub-feature count of current feature."""
        self.__class__._ip_count = 0

    def unlock_properties(self):
        """
        Unlock all Prop/Items of the IP
        """
        for prop in list(self.prop_list.values()):
            prop.unlock_items()

    def lock_properties(self):
        """
        Lock all Prop/Items of the IP
        """
        for prop in list(self.prop_list.values()):
            prop.lock_items()

    def unlock_ip(self):
        """
        Unlock all Prop/Items of the IP.
        """
        self.unlock_properties()

    def prep_to_save(self):
        """
        Trick used to ensure pickle output file stability
        Pickle doesn't provide reproducible output for dicts. When saved, they are converted
        to lists.
        """
        self.rfu_list = sorted(list(self.prop_list.items()), key=lambda key: key[0])
        self.prop_list = {}

    def post_load(self):
        """
        Trick used to ensure pickle output file stability
        When loading saved db, lists are converted back to initial dicts.
        """
        for prop_key, prop_elt in self.rfu_list:
            self.prop_list[prop_key] = prop_elt
        self.rfu_list = []

    def create_ip_tag_dict(self):
        """Create a tag->item dictionary of the current feature."""
        ip_tag_dict = {}
        for prop in list(self.prop_list.values()):
            for item in list(prop.item_list.values()):
                ip_tag_dict[item.tag] = item
        return ip_tag_dict
