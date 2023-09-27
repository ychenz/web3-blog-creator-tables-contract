import { ethers } from "hardhat";

async function main() {
  const blogTablesContract = await ethers.getContractFactory("BlogCreator");
  // Deploy using #0 hardhat account 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
  const blogTables = await blogTablesContract.deploy();

  await blogTables.deployed();
  console.log(`Contract deployed to '${blogTables.address}'.\n`);

  let tableName = await blogTables.CreatorSiteTableName();
  console.log(`Table name '${tableName}' minted to contract.`);

  tableName = await blogTables.CreatorBlogTableName();
  console.log(`Table name '${tableName}' minted to contract.`);

  tableName = await blogTables.CreatorMembershipTiersTableName();
  console.log(`Table name '${tableName}' minted to contract.`);

  tableName = await blogTables.UserSiteSubscriptionsTableName();
  console.log(`Table name '${tableName}' minted to contract.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
