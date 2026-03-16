# WinRouter - Utilitários
# Convenção de nomenclatura NAT: WR-NAT-{base}
#
# Este arquivo fornece funções utilitárias para padronização de nomes
# e identificação de regras NAT pertencentes ao WinRouter.

# -----------------------------------------------------------------------------
# Get-NatRuleName
# -----------------------------------------------------------------------------
function Get-NatRuleName {
    <#
    .SYNOPSIS
    Gera o nome padrao da regra NAT baseado no prefixo de rede.
    Unica fonte de verdade para nomenclatura no projeto.

    .DESCRIPTION
    Segue a convencao WR-NAT-{base} onde {base} e o terceiro octeto
    do prefixo de rede. Exemplos:
      192.168.50.0/24 → WR-NAT-50
      192.168.60.0/24 → WR-NAT-60
      192.168.70.0/24 → WR-NAT-70

    .PARAMETER NetworkPrefix
    Prefixo de rede no formato CIDR (ex: "192.168.60.0/24")

    .EXAMPLE
    Get-NatRuleName -NetworkPrefix "192.168.60.0/24"
    Retorna: "WR-NAT-60"

    .EXAMPLE
    Get-NatRuleName -NetworkPrefix "192.168.50.0/24"
    Retorna: "WR-NAT-50"

    .NOTES
    Convencao adotada em 2026-03-15
    Prefixo 'WR-' identifica regras como propriedade do WinRouter
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\.\d+/\d+$')]
        [string]$NetworkPrefix
    )

    # Extrai o terceiro octeto: 192.168.60.0 → 60
    $base = ($NetworkPrefix -split '\.')[2]

    return "WR-NAT-$base"
}

# -----------------------------------------------------------------------------
# Test-IsOwnedNatRule
# -----------------------------------------------------------------------------
function Test-IsOwnedNatRule {
    <#
    .SYNOPSIS
    Retorna $true se a regra NAT foi criada por este projeto.
    Usado para proteger regras externas em operacoes de remocao.

    .DESCRIPTION
    Verifica se o nome da regra NAT segue a convencao WR-NAT-{base}.
    Regras que nao seguem este padrao sao consideradas externas e
    nao devem ser removidas automaticamente.

    .PARAMETER NatName
    Nome da regra NAT a ser verificada

    .EXAMPLE
    Test-IsOwnedNatRule -NatName "WR-NAT-60"
    Retorna: $true

    .EXAMPLE
    Test-IsOwnedNatRule -NatName "NAT-Rede50-DESKTOP"
    Retorna: $false

    .EXAMPLE
    Test-IsOwnedNatRule -NatName "Rede60"
    Retorna: $false

    .NOTES
    Protege regras externas durante operacoes de fallback nuke
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NatName
    )

    return $NatName -match '^WR-NAT-\d+'
}

# -----------------------------------------------------------------------------
# Get-NatBaseFromPrefix
# -----------------------------------------------------------------------------
function Get-NatBaseFromPrefix {
    <#
    .SYNOPSIS
    Extrai a base (terceiro octeto) de um prefixo de rede.

    .PARAMETER NetworkPrefix
    Prefixo de rede no formato CIDR (ex: "192.168.60.0/24")

    .EXAMPLE
    Get-NatBaseFromPrefix -NetworkPrefix "192.168.60.0/24"
    Retorna: "60"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NetworkPrefix
    )

    return ($NetworkPrefix -split '\.')[2]
}

# -----------------------------------------------------------------------------
# Notas: Export é feito pelo WinRouter.psm1 via dot-source
# As funcoes sao automaticamente disponiveis quando o modulo principal e carregado
# -----------------------------------------------------------------------------
