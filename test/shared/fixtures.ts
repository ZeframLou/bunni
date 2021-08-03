import { ethers } from "hardhat";
import { Fixture } from "ethereum-waffle";

import { Greeter, Greeter__factory } from "../../typechain";

interface GreeterFixture {
  greeter: Greeter;
}

export const greeterFixture: Fixture<GreeterFixture> = async function(): Promise<GreeterFixture> {
  const greeterFactory = (await ethers.getContractFactory(
    "Greeter"
  )) as Greeter__factory;
  const greeter = await greeterFactory.deploy("Hello, world!");
  await greeter.deployed();
  return { greeter };
};
