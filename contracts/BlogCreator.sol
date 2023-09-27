// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10 <0.9.0;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TablelandController} from "@tableland/evm/contracts/TablelandController.sol";
import {TablelandPolicy} from "@tableland/evm/contracts/TablelandPolicy.sol";
import {TablelandDeployments} from "@tableland/evm/contracts/utils/TablelandDeployments.sol";
import {SQLHelpers} from "@tableland/evm/contracts/utils/SQLHelpers.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

error BlogCreator__SendMoreToSubscribe();

// Starter template for contract owned and controlled tables
contract BlogCreator is TablelandController, ERC721Holder {
    /** Contract variables */
    address public immutable i_owner;

    struct MembershipTierInfo {
        uint256 monthlyPrice;
        address creatorAddress;
    }

    mapping(uint32 => MembershipTierInfo) public creatorMembershipTierIdToTierMonthlyPrice;

    /** Table land tabls */
    // The table token ID, assigned upon `TablelandTables` minting a table
    uint256 private immutable _creatorSiteTableId;
    // Table prefix for the table (custom value)
    string private constant _CREATOR_SITE_TABLE_PREFIX = "creator_site";

    uint256 private immutable _creatorBlogTableId;
    string private constant _CREATOR_BLOG_TABLE_PREFIX = "creator_blog";

    uint256 private immutable _creatorMembershipTiersTableId;
    string private constant _CREATOR_MEMBERSHIP_TIERS_TABLE_PREFIX = "creator_membership_tiers";

    uint256 private immutable _userSiteSubscriptionsTableId;
    string private constant _USER_SITE_SUBSCRIPTIONS_TABLE_PREFIX = "user_site_subscriptions";

    // Constructor that creates a table, sets the controller, and inserts data
    // Could be great if we can generate this from a relation schema
    constructor() {
        i_owner = msg.sender;

        _creatorSiteTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
            "id integer primary key,"
            "site_name text,"
            "site_cid text," // Notice the trailing comma
            "creator_address text",
            _CREATOR_SITE_TABLE_PREFIX
            )
        );

        _creatorBlogTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
            "id integer primary key,"
            "creator_site_id integer,"
            "creator_membership_tier_id integer,"
            "blog_cid text,"
            "blog_name text,"
            "creator_address text",
            _CREATOR_BLOG_TABLE_PREFIX
            )
        );

        _creatorMembershipTiersTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
            "id integer primary key,"
            "creator_site_id integer,"
            "creator_address text,"
            "tier_name text UNIQUE,"
            "tier_description text,"
            "tier_monthly_price integer",
            _CREATOR_MEMBERSHIP_TIERS_TABLE_PREFIX
            )
        );

        _userSiteSubscriptionsTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
            "id integer primary key,"
            "creator_membership_tier_id integer,"
            "subscription_activation_timestamp integer,"
            "user_address text",
            _USER_SITE_SUBSCRIPTIONS_TABLE_PREFIX
            )
        );

        // Set the ACL controller to enable writes to others besides the table owner
        TablelandDeployments.get().setController(
            address(this), // Table owner, i.e., this contract
            _creatorSiteTableId,
            address(this) // Set the controller address—also this contract
        );

        TablelandDeployments.get().setController(
            address(this),
            _creatorBlogTableId,
            address(this)
        );

        TablelandDeployments.get().setController(
            address(this),
            _creatorMembershipTiersTableId,
            address(this)
        );

        // Only this contract can write to the table, after user has paid for the subscription
        TablelandDeployments.get().setController(
            address(this),
            _userSiteSubscriptionsTableId,
            address(this)
        );
    }

    /** User Subscription contract logics */
    function subscribe(address userAddress, uint32 membershipTierId) public payable {
        // 1. Get membership tier price using id
        MembershipTierInfo memory membershipTierInfo = creatorMembershipTierIdToTierMonthlyPrice[membershipTierId];

        // 2. Check if user has send enough fund
        if (msg.value < membershipTierInfo.monthlyPrice) {
            revert BlogCreator__SendMoreToSubscribe();
        }

        // 3. Move fund from user to the creator (TODO: Potentially charge fee in future when run this on mainnet)
        (
            bool callSuccess,
            // bytes memory dataReturned
        ) = payable(membershipTierInfo.creatorAddress).call{value: msg.value}("");
        require(callSuccess, "Failed to subscribe");

        // 4. Insert into user subscription table with the membership tier id
        insertIntoUserSiteSubscriptionsTable(membershipTierId, userAddress);
    }

    /**
     * @dev We need to register the monthly price right after the membership tier is created,
     *  since we currenly have no way to query the price from table on chain when calling the
     *  subscription smart contract method
     */
    function registerMembershipTier(uint32 tierId, uint256 monthlyPrice, address creatorAddress) public {
        creatorMembershipTierIdToTierMonthlyPrice[tierId] = MembershipTierInfo(monthlyPrice, creatorAddress);
    }

    function getMembershipTierInfor(uint32 tierId) public view returns (string memory) {
        MembershipTierInfo memory tierInfo = creatorMembershipTierIdToTierMonthlyPrice[tierId];

        return string.concat(
            "MembershipTier ID:",
            Strings.toString(tierId),
            "; Price:",
            Strings.toString(tierInfo.monthlyPrice),
            "; CreatorAddress:",
            Strings.toHexString(tierInfo.creatorAddress)
        );
    }

    /** SQL DB Methods */
    function CreatorSiteTableName() external view returns (string memory) {
        return SQLHelpers.toNameFromId(_CREATOR_SITE_TABLE_PREFIX, _creatorSiteTableId);
    }

    function CreatorBlogTableName() external view returns (string memory) {
        return SQLHelpers.toNameFromId(_CREATOR_BLOG_TABLE_PREFIX, _creatorBlogTableId);
    }

    function CreatorMembershipTiersTableName() external view returns (string memory) {
        return SQLHelpers.toNameFromId(_CREATOR_MEMBERSHIP_TIERS_TABLE_PREFIX, _creatorMembershipTiersTableId);
    }

    function UserSiteSubscriptionsTableName() external view returns (string memory) {
        return SQLHelpers.toNameFromId(_USER_SITE_SUBSCRIPTIONS_TABLE_PREFIX, _userSiteSubscriptionsTableId);
    }

    // Let any creator create a blog site
    function insertIntoCreatorSiteTable(string memory siteName, string memory siteCid, address creatorAddress) external {
        TablelandDeployments.get().mutate(
            address(this),
            _creatorSiteTableId,
            SQLHelpers.toInsert(
                _CREATOR_SITE_TABLE_PREFIX,
                _creatorSiteTableId,
                "site_name, site_cid,creator_address",
                string.concat(
                    SQLHelpers.quote(siteName),
                    ",",
                    SQLHelpers.quote(siteCid),
                    ",",
                    SQLHelpers.quote(Strings.toHexString(creatorAddress))
                )
            )
        );
    }

    function insertIntoCreatorBlogTable(string memory blogCid, string memory blogName, address creatorAddress, uint32 creatorSiteId, uint32 creatorMembershipTierId) external {
        TablelandDeployments.get().mutate(
            address(this),
            _creatorBlogTableId,
            SQLHelpers.toInsert(
                _CREATOR_BLOG_TABLE_PREFIX,
                _creatorBlogTableId,
                "creator_site_id, blog_cid, blog_name, creator_address, creator_membership_tier_id",
                string.concat(
                    Strings.toString(creatorSiteId),
                    ",",
                    SQLHelpers.quote(blogCid),
                    ",",
                    SQLHelpers.quote(blogName),
                    ",",
                    SQLHelpers.quote(Strings.toHexString(creatorAddress)),
                    ",",
                    Strings.toString(creatorMembershipTierId)
                )
            )
        );
    }

    function insertFreeBlogIntoCreatorBlogTable(string memory blogCid, string memory blogName, address creatorAddress, uint32 creatorSiteId) external {
        TablelandDeployments.get().mutate(
            address(this),
            _creatorBlogTableId,
            SQLHelpers.toInsert(
                _CREATOR_BLOG_TABLE_PREFIX,
                _creatorBlogTableId,
                "creator_site_id, blog_cid, blog_name, creator_address",
                string.concat(
                    Strings.toString(creatorSiteId),
                    ",",
                    SQLHelpers.quote(blogCid),
                    ",",
                    SQLHelpers.quote(blogName),
                    ",",
                    SQLHelpers.quote(Strings.toHexString(creatorAddress))
                )
            )
        );
    }

    function insertIntoCreatorMembershipTiersTable(
        uint32 creatorSiteId,
        address creatorAddress,
        string memory tierName,
        string memory tierDescription,
        // price in WEI
        uint256 tierMonthlyPrice
    ) external {
        TablelandDeployments.get().mutate(
            address(this),
            _creatorMembershipTiersTableId,
            SQLHelpers.toInsert(
                _CREATOR_MEMBERSHIP_TIERS_TABLE_PREFIX,
                _creatorMembershipTiersTableId,
                "creator_site_id, creator_address, tier_name, tier_description, tier_monthly_price",
                string.concat(
                    Strings.toString(creatorSiteId),
                    ",",
                    SQLHelpers.quote(Strings.toHexString(creatorAddress)),
                    ",",
                    SQLHelpers.quote(tierName),
                    ",",
                    SQLHelpers.quote(tierDescription),
                    ",",
                    Strings.toString(tierMonthlyPrice)
                )
            )
        );
    }

    // Only this contract can write to the table, after user has paid for the subscription
    function insertIntoUserSiteSubscriptionsTable(uint32 creatorMembershipTierId, address userAddress) internal {
        TablelandDeployments.get().mutate(
            address(this),
            _userSiteSubscriptionsTableId,
            SQLHelpers.toInsert(
                _USER_SITE_SUBSCRIPTIONS_TABLE_PREFIX,
                _userSiteSubscriptionsTableId,
                "creator_membership_tier_id, user_address, subscription_activation_timestamp",
                string.concat(
                    Strings.toString(creatorMembershipTierId),
                    ",",
                    SQLHelpers.quote(Strings.toHexString(userAddress)),
                    ",",
                    Strings.toString(block.timestamp)
                )
            )
        );
    }

    // Update a row in the table from an external call (set `val` at any `id`)
    // function updateVal(uint64 id, string memory val) external {
    //     string memory setters = string.concat("val=", SQLHelpers.quote(val));
    //     string memory filters = string.concat("id=", Strings.toString(id));
    //     // Mutate a row at `id` with a new `val`
    //     TablelandDeployments.get().mutate(
    //         address(this),
    //         tableId,
    //         SQLHelpers.toUpdate(_TABLE_PREFIX, tableId, setters, filters)
    //     );
    // }

    // // Delete a row in the table from an external call (delete at any `id`)
    // function deleteVal(uint64 id) external {
    //     string memory filters = string.concat("id=", Strings.toString(id));
    //     // Mutate by deleting the row at `id`
    //     TablelandDeployments.get().mutate(
    //         address(this),
    //         tableId,
    //         SQLHelpers.toDelete(_TABLE_PREFIX, tableId, filters)
    //     );
    // }

    // Dynamic ACL controller policy that allows any inserts and updates
    function getPolicy(
        address,
        uint256
    ) public payable override returns (TablelandPolicy memory) {
        // Restrict updates to a single column, e.g., `val`
        string[] memory updatableColumns = new string[](1);
        updatableColumns[0] = "val";
        // Return the policy
        return
            TablelandPolicy({
                allowInsert: true,
                allowUpdate: true,
                // disallow delete site since we are creating a perma site on Lighthouse
                allowDelete: false,
                whereClause: "", // Apply WHERE conditions
                withCheck: "", // Apply CHECK conditions
                updatableColumns: updatableColumns
            });
    }
}
