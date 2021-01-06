const Lachesis = artifacts.require('Lachesis')
const OpenArbiter = artifacts.require('OpenArbiter')
const Behodler = artifacts.require('Behodler')
const LiquidityReceiver = artifacts.require('LiquidityReceiver')
const AddressBalanceCheck = artifacts.require('AddressBalanceCheck')
const ABDK = artifacts.require('ABDK')

const fs = require('fs')
module.exports = async function (deployer, network, accounts) {
    var lachesisInstance, openArbiterInstance, behodlerInstance, liquidityReceiverInstance

    await deployer.deploy(Lachesis)
    lachesisInstance = await Lachesis.deployed();

    await deployer.deploy(OpenArbiter)
    openArbiterInstance = await OpenArbiter.deployed()

    await deployer.deploy(LiquidityReceiver)
    liquidityReceiverInstance = await LiquidityReceiver.deployed();

    await deployer.deploy(AddressBalanceCheck)
    await deployer.link(AddressBalanceCheck, Behodler)

    await deployer.deploy(ABDK)
    await deployer.link(ABDK, Behodler)

    await deployer.deploy(Behodler)
    behodlerInstance = await Behodler.deployed()

    await lachesisInstance.setBehodler(behodlerInstance.address)
    var tokens = getTokenAddresses()
    var weiDaiStuff = getWeiDaiStuff()
    var wethAddress = getWeth(tokens)

    await behodlerInstance.configureScarcity(110, 25, accounts[0])
    await behodlerInstance.seed(wethAddress,
        lachesisInstance.address,
        openArbiterInstance.address,
        liquidityReceiverInstance.address,
        weiDaiStuff.inertReserve,
        weiDaiStuff.dai)

    for (let i = 0; i < tokens.length; i++) {
        await lachesisInstance.measure(tokens[i], true, false)
        await lachesisInstance.updateBehodler(tokens[i])
    }

    await lachesisInstance.measure(weiDaiStuff['weiDai'], true, false)
    await lachesisInstance.updateBehodler(weiDaiStuff['weiDai'])
    console.log('BEHODLER 2 MIGRATION COMPLETE')
}


function getTokenAddresses() {
    const location = './Behodler1mappings.json'
    const content = fs.readFileSync(location, 'utf-8')
    const structure = JSON.parse(content)
    const list = structure.filter(s => s.name == 'development')[0].list
    const predicate = (item) => item.contract.startsWith('Mock')
    const behodlerAddresses = list.filter(predicate).map(item => item.address)
    return behodlerAddresses
}

function getWeth() {
    const location = './Behodler1mappings.json'
    const content = fs.readFileSync(location, 'utf-8')
    const structure = JSON.parse(content)
    const list = structure.filter(s => s.name == 'development')[0].list
    const predicate = (item) => item.contract === ('MockWeth')
    return list.filter(predicate)[0].address
}

function getWeiDaiStuff() {
    return JSON.parse(fs.readFileSync('weidai.json', 'utf-8'))
}