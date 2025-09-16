exports.handler = async (event) => {
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Lambda function placeholder',
            input: event
        })
    };
};