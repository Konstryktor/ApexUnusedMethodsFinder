public class UmlService 
{
    
    private static List<ToolingAPI.ApexClass> executeCalloutQueryForApexClass(final string className)
    {
        return (List<ToolingAPI.ApexClass>) 
                new ToolingApi().query(
                    'Select Name, SymbolTable ' + 
                    'From ApexClass ' + 
                   'Where Name = \'' + className + '\'').records;
    }

    /**
     * Helper to turn a bad SaveResult into an exception
     **/
    private static UmlServiceException makeException(final ToolingAPI.SaveResult saveResult)
    {
        String message = '';
        
        for (ToolingAPI.Error error : saveResult.errors)
        {
            message += error.message + String.join(error.fields, ',') + '\n';
        }
        
        return new UmlServiceException(message);
    }

    private static UmlServiceException makeException(final ToolingApi.ToolingAPIAuthorizationException tapiae)
    {
        string message = 'In order to use ApexUML, you must establish a Remote Site entry for \''+System.Url.getSalesforceBaseUrl().toExternalForm()+'\'';
        return new UmlServiceException(message);
    }
    
    public static void compile(String className, Id containerId)
    {
        // Retrieve the ApexClass Body
        Map<String, ApexClass> classes = 
            new ApexClassesSelector().selectByName(new List<String> { className }); 

        if (classes.isEmpty())
        {
            throw new UmlServiceException('Apex Class ' + className + ' not found');
        }

        // Delete any existing MetadataContainer?
        ToolingApi tooling = new ToolingApi();
        
        

        // Create MetadataContainer
        

        // Create ApexClassMember and associate them with the MetadataContainer
        ToolingAPI.ApexClassMember apexClassMember = new ToolingAPI.ApexClassMember();
        
        apexClassMember.Body = classes.get(className).Body;
        apexClassMember.ContentEntityId = classes.get(className).id;
        apexClassMember.MetadataContainerId = containerId;
        
        ToolingAPI.SaveResult apexClassMemberSaveResult = tooling.createSObject(apexClassMember);
        
        if ( ! apexClassMemberSaveResult.success )
        {
            throw makeException(apexClassMemberSaveResult);
        }

        // Create ContainerAysncRequest to deploy (check only) the Apex Classes and thus obtain the SymbolTable's
        
                
        //return asyncRequest;
    }

    
    public class UmlServiceException extends Exception { }

}