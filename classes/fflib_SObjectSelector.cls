public abstract with sharing class fflib_SObjectSelector
{
    /**
     * This overrides the Multi Currency handling, preventing it from injecting the CurrencyIsoCode field for certain System objects that don't ever support it
     **/
    private static Set<String> STANDARD_WITHOUT_CURRENCYISO = new Set<String> { 'ApexClass', 'AsyncApexJob' };
        
    private fflib_StringBuilder.FieldListBuilder m_fieldListBuilder;
    
    private Boolean m_includeFieldSetFields;
    
    /**
     * Implement this method to inform the base class of the SObject (custom or standard) to be queried
     **/
    abstract Schema.SObjectType getSObjectType();
    
    /**
     * Implement this method to inform the base class of the common fields to be queried or listed by the base class methods
     **/
    abstract List<Schema.SObjectField> getSObjectFieldList();

    /**
     * Constructs the Selector, defaults to not including any FieldSet fields automatically
     **/
    public fflib_SObjectSelector()
    {
        this(false);
    }
    
    /**
     * Constructs the Selector
     *
     * @param includeFieldSetFields Set to true if the Selector queries are to include Fieldset fields as well 
     **/
    public fflib_SObjectSelector(Boolean includeFieldSetFields)
    {
        m_includeFieldSetFields = includeFieldSetFields;
    }

    /**
     * Override this method to provide a list of Fieldsets that can optionally drive inclusion of additional fields in the base queries
     **/
    public virtual List<Schema.FieldSet> getSObjectFieldSetList()
    {
        return null;
    }
    
    /**
     * Override this method to control the default ordering of records returned by the base queries, defaults to Name
     **/
    public virtual String getOrderBy()
    {
        return 'Name';
    }

    /**
     * Provides access to the builder containing the list of fields base queries are using, this is demand
     *   created if one has not already been defined via setFieldListBuilder
     **/
    public fflib_StringBuilder.FieldListBuilder getFieldListBuilder()
    {
        // Demand create the FieldListBuilder unless one has already been set?
        if(m_fieldListBuilder == null)
            m_fieldListBuilder = STANDARD_WITHOUT_CURRENCYISO.contains(getSObjectType().getDescribe().getName()) ?
                new fflib_StringBuilder.FieldListBuilder( 
                    getSObjectFieldList(), m_includeFieldSetFields ? getSObjectFieldSetList() : null) : 
                new fflib_StringBuilder.MultiCurrencyFieldListBuilder( 
                    getSObjectFieldList(), m_includeFieldSetFields ? getSObjectFieldSetList() : null);
        
        return m_fieldListBuilder;
    }

    /**
     * Use this method to override the default FieldListBuilder (created on demand via getFieldListBuilder) with a custom one, 
     *   warning, this will bypass anything getSObjectFieldList or getSObjectFieldSetList returns
     **/    
    /*public void setFieldListBuilder(fflib_StringBuilder.FieldListBuilder fieldListBuilder)
    {
        m_fieldListBuilder = fieldListBuilder;
    }*/

    /**
     * Returns in string form a comma delimted list of fields as defined via getSObjectFieldList and optionally getSObjectFieldSetList
     **/    
    public String getFieldListString()
    {
        return getFieldListBuilder().getStringValue();
    }
    
    /**
     * Returns in string form a comma delimted list of fields as defined via getSObjectFieldList and optionally getSObjectFieldSetList
     * @param relation Will prefix fields with the given relation, e.g. MyLookupField__r
     **/    
    /*public String getRelatedFieldListString(String relation)
    {
        return getFieldListBuilder().getStringValue(relation + '.');
    }*/
    
    /**
     * Returns the string representaiton of the SObject this selector represents
     **/
    public String getSObjectName()
    {
        return getSObjectType().getDescribe().getName();
    }
    
    /**
     * Performs a SOQL query, 
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included) 
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     * @returns A list of SObject's
     **/
    /*public List<SObject> selectSObjectsById(Set<Id> idSet)
    {
        assertIsAccessible();
        return Database.query(buildQuerySObjectById());
    }*/
        
    /**
     * Performs a SOQL query, 
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included) 
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     * @returns A QueryLocator (typically for use in a Batch Apex job)
     **/
    /*public Database.QueryLocator queryLocatorById(Set<Id> idSet)
    {
        assertIsAccessible();
        return Database.getQueryLocator(buildQuerySObjectById());
    }*/
    
    /**
     * Throws an exception if the SObject indicated by getSObjectType is not accessible to the current user (read access) 
     **/
    public void assertIsAccessible()
    {
        if(!getSObjectType().getDescribe().isAccessible()) {}
           /*throw new fflib_SObjectDomain.DomainException(
                'Permission to access an ' + getSObjectType().getDescribe().getName() + ' dennied.');*/       
        
    }

    /**
     * Constructs the default SOQL query for this selector, see selectSObjectsById and queryLocatorById
     **/    
    private String buildQuerySObjectById()
    {   
        return String.format('SELECT {0} FROM {1} WHERE id in :idSet ORDER BY {2}', 
            new List<String>{getFieldListString(),getSObjectName(),getOrderBy()});      
    }
}